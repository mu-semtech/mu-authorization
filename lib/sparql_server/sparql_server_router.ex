defmodule SparqlServer.Router do
  @moduledoc """
  The router for the SPARQL endpoint.
  """
  use Plug.Router
  require Logger
  require ALog

  plug :match
  plug :dispatch

  def init(args) do
    args
  end

  defp get_query_from_post( conn, body ) do
    if Plug.Conn.get_req_header(conn, "content-type") == ["application/sparql-update"] do
      { :update, body }
    else
      body_params = URI.decode_query( body )
      cond do
        body_params["query"] -> { :any, body_params["query"] } # apparently this can be both :query as well as :update in practice
        body_params["update"] -> { :update, body_params["update"] }
        true ->
          params =
            conn.query_string
            |> URI.decode_query
          { :any, params["query"] }
      end
    end
  end

  # TODO these methods are still very similar, I need to spent time
  #      to get the proper abstractions out
  post "/sparql" do
    {:ok, body, _} = read_body(conn)

    ALog.di conn, "Received POST connection"
    conn = process_request_headers( conn )

    { method, query } = get_query_from_post( conn, body ) |> ALog.di( "Received query" )

    { conn, response } = handle_query query, method, conn

    ALog.di conn.req_headers, "Request headers"
    ALog.di conn.resp_headers, "Response headers"
    ALog.di response, "Response content"

    _session_id =
      conn
      |> Plug.Conn.get_req_header( "mu-session-id" )
      |> List.first
      |> ALog.di( "session id" )

    conn
    # |> put_resp_content_type( "application/json" )
    |> put_resp_content_type( "application/sparql-results+json" )
    |> send_resp(200, response)
  end

  get "/sparql" do
    params = conn.query_string |> URI.decode_query

    ALog.di conn, "Received GET connection"
    conn = process_request_headers( conn )

    query = params["query"]

    { conn, response } = handle_query query, :query, conn

    ALog.di conn.req_headers, "Request headers"
    ALog.di conn.resp_headers, "Response headers"
    ALog.di response, "Response content"

    conn
    # |> put_resp_content_type( "application/json" )
    |> put_resp_content_type( "application/sparql-results+json" )
    |> send_resp(200, response)
  end

  match _, do: send_resp(conn, 404, "404 error not found")

  defp calculate_access_groups( conn ) do
    # Calculates the access groups for the given connection and pushes
    # them on the connection itself.
    access_groups = get_access_groups( conn )

    conn = if access_groups != :sudo do
      Plug.Conn.put_resp_header(
        conn,
        "mu-auth-allowed-groups",
        encode_json_access_groups( access_groups ) )
    else
      conn
    end

    ALog.ii access_groups, "Access groups"

    { conn, access_groups }
  end

  # TODO for now this method does not apply our access constraints
  defp handle_query(query, kind, conn) do
    top_level_key = case kind do
                      :query -> :QueryUnit
                      :update -> :UpdateUnit
                      :any -> :Sparql
                    end

    parsed_form =
      query
      |> ALog.di( "Raw received query" )
      |> String.trim
      |> String.replace( "\r", "" ) # TODO: check if this is valid and/or ensure parser skips \r between words.
      |> Parser.parse_query_full( top_level_key )
      |> ALog.di( "Parsed query" )
      |> wrap_query_in_toplevel
      |> ALog.di( "Wrapped parsed query" )

    { conn, new_parsed_forms } =
      if is_select_query( parsed_form ) do
        manipulate_select_query( parsed_form, conn )
      else
        manipulate_update_query( parsed_form, conn )
      end

    encoded_response =
      new_parsed_forms
      |> ALog.di( "New parsed forms" )
      |> Enum.reduce( true, fn( elt, _ ) ->
        elt
        |> Regen.result
        |> ALog.di( "Posing query to backend" )
        |> SparqlClient.query
      end )
      |> Poison.encode!

    { conn, encoded_response }
  end

  def wrap_query_in_toplevel( %InterpreterTerms.SymbolMatch{ symbol: :Sparql } = matched ) do
    matched
  end
  def wrap_query_in_toplevel( %InterpreterTerms.SymbolMatch{ string: str } = matched ) do
    # Only public for benchmark
    %InterpreterTerms.SymbolMatch{
      symbol: :Sparql,
      string: str,
      submatches: [matched]
    }
  end

  defp get_access_groups( conn ) do
    access_groups = Plug.Conn.get_req_header( conn, "mu-auth-allowed-groups" )
    is_sudo = not Enum.empty?( Plug.Conn.get_req_header( conn, "mu-auth-sudo" ) )

    cond do
      is_sudo -> :sudo
      Enum.empty?( access_groups ) ->
        Acl.UserGroups.Config.user_groups
        |> Acl.user_authorization_groups( conn )
        |> ALog.di( "Fresh authorization groups" )
      true ->
        access_groups
        |> List.first
        |> decode_json_access_groups
        |> ALog.di( "Decoded authorization groups" )
    end
  end

  defp is_select_query( query ) do
    case query do
      %InterpreterTerms.SymbolMatch{
        symbol: :Sparql,
        submatches: [
          %InterpreterTerms.SymbolMatch{
            symbol: :QueryUnit} ]} -> true
      _ -> false
    end
  end

  defp manipulate_select_query( query, conn ) do
    { conn, authorization_groups } = calculate_access_groups( conn )

    # TODO: apply Acl.UserGroups.Config to select queries
    { conn, query } = if authorization_groups == :sudo do
      { conn, query }
    else
      { query, _access_groups } =
        query
        |> Manipulators.SparqlQuery.remove_from_statements # TODO: check how BaseDecl should be interpreted, possibly also remove that.
        |> Acl.process_query( Acl.UserGroups.for_use(:read), authorization_groups )

      conn = Plug.Conn.put_resp_header( conn, "mu-auth-used-groups", encode_json_access_groups(authorization_groups) )
      { conn, query }
    end

    { conn, [ query ] }
  end

  defp manipulate_update_query( query, conn ) do
    Logger.debug( "This is an update query" )

    { conn, authorization_groups } = calculate_access_groups( conn )

    # TODO DRY into/from Updates.QueryAnalyzer.insert_quads

    # TODO: Check where the default_graph is used where these options are passed and verify whether this is a sensible name.
    options = %{
      default_graph: Updates.QueryAnalyzer.Iri.from_iri_string( "<http://mu.semte.ch/application>", %{} ),
      prefixes: %{ "xsd" => Updates.QueryAnalyzer.Iri.from_iri_string("<http://www.w3.org/2001/XMLSchema#>"),
                   "foaf" => Updates.QueryAnalyzer.Iri.from_iri_string("<http://xmlns.com/foaf/0.1/>") }
    }

    executable_queries =
      query
      |> ALog.di( "Parsed query" )
      |> Updates.QueryAnalyzer.quads( %{
          default_graph: Updates.QueryAnalyzer.Iri.from_iri_string( "<http://mu.semte.ch/application>", %{} ),
          authorization_groups: authorization_groups } )
      |> Enum.reject( &match?( {_,[]}, &1 ) )
      |> ALog.di( "Non-empty operations" )
      |> Enum.map(
        fn ({statement, quads}) ->
          ALog.di quads, "detected quads"
          ALog.di statement, "quads operation"

          processed_quads = enforce_write_rights( quads, authorization_groups  )

          { statement, processed_quads }
        end)
      |> Delta.publish_updates
      |> Enum.map(
        fn ({statement, processed_quads}) ->
          case statement do
            :insert ->
              Updates.QueryAnalyzer.construct_insert_query_from_quads( processed_quads, options )
            :delete ->
              Updates.QueryAnalyzer.construct_delete_query_from_quads( processed_quads, options )
          end end )

      { conn, executable_queries }
  end

  defp enforce_write_rights( quads, authorization_groups ) do
    user_groups_for_update = Acl.UserGroups.for_use( :write )

    processed_quads =
      quads
      |> Acl.process_quads_for_update( user_groups_for_update, authorization_groups )
      |> elem(1)
      |> ALog.di( "processed quads" )

    processed_quads
  end

  def decode_json_access_groups( json_string ) do
    json_string
    |> Poison.decode!
    |> Enum.map( fn (%{"name" => name, "variables" => variables}) -> {name, variables} end )
  end

  defp process_request_headers( conn ) do
    new_request_headers =
      conn
      |> Map.get(:req_headers)
      |> Enum.map( fn {name, val} -> { String.downcase( name ), val } end )

    conn
    |> Map.put( :req_headers, new_request_headers )
  end

  defp encode_json_access_groups( access_groups ) do
    access_groups
    |> Enum.map( fn ({name, variables}) ->
      %{ "name" => name, "variables" => variables }
    end)
    |> Poison.encode!
  end

end
