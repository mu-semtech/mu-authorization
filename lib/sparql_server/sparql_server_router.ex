defmodule SparqlServer.Router do
  @moduledoc """
  The router for the SPARQL endpoint.
  """
  use Plug.Router
  require Logger

  plug :match
  plug :dispatch

  def init(args) do
    args
  end

  # TODO these methods are still very similar, I need to spent time
  #      to get the proper abstractions out
  post "/sparql" do
    {:ok, body_params_encoded, _} = read_body(conn)

    body_params = body_params_encoded |> URI.decode_query

    query = body_params["query"] |> IO.inspect( label: "Received query" )

    { conn, response } = handle_query query, conn

    conn
    |> put_resp_content_type( "application/json" )
    |> send_resp(200, response)
  end

  get "/sparql" do
    params = conn.query_string |> URI.decode_query

    query = params["query"]

    { conn, response } = handle_query query, conn

    conn
    |> put_resp_content_type( "application/json" )
    |> send_resp(200, response)
  end

  match _, do: send_resp(conn, 404, "404 error not found")

  # TODO for now this method does not apply our access constraints
  defp handle_query(query, conn) do
    access_groups = get_access_groups( conn )

    conn = Plug.Conn.put_resp_header(
      conn,
      "mu-authorization-groups",
      encode_json_access_groups( access_groups ) )

    parsed_form =
      query
      |> String.trim
      |> String.replace( "\r", "" ) # TODO: check if this is valid and/or ensure parser skips \r between words.
      |> Parser.parse_query_full

    new_parsed_forms = if is_select_query( parsed_form ) do
      manipulate_select_query( parsed_form, conn, access_groups )
    else
      manipulate_update_query( parsed_form, conn, access_groups )
    end

    encoded_response =
      new_parsed_forms
      |> Enum.reduce( true, fn( elt, _ ) ->
        elt
        |> Regen.result
        |> SparqlClient.query
      end )
      |> Poison.encode!

    { conn, encoded_response }
  end

  defp get_access_groups( conn ) do
    access_groups = Plug.Conn.get_req_header( conn, "mu-authorization-groups" )

    if Enum.empty?( access_groups ) do
      Acl.Config.UserGroups.user_groups
      |> Acl.user_authorization_groups( conn )
    else
      access_groups
      |> List.first
      |> decode_json_access_groups
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

  defp manipulate_select_query( query, _conn, authorization_groups ) do
    # TODO: apply Acl.Config.UserGroups to select queries
    { query, _access_groups } =
      query
      |> Manipulators.SparqlQuery.remove_graph_statements
      |> Manipulators.SparqlQuery.remove_from_statements # TODO: check how BaseDecl should be interpreted, possibly also remove that.
      |> Acl.process_query( Acl.Config.UserGroups.user_groups, authorization_groups )

    [ query ]
  end

  defp manipulate_update_query( query, conn, authorization_groups ) do
    # TODO DRY into/from Updates.QueryAnalyzer.insert_quads

    # TODO: Check where the default_graph is used where these options are passed and verify whether this is a sensible name.
    options = %{ default_graph: Updates.QueryAnalyzer.Iri.from_iri_string( "<http://mu.semte.ch/application>", %{} ) }   
    query
    |> Updates.QueryAnalyzer.quads( %{
          default_graph: Updates.QueryAnalyzer.Iri.from_iri_string( "<http://mu.semte.ch/application>", %{} ),
          authorization_groups: authorization_groups } )
    |> Enum.reject( &match?( {_,[]}, &1 ) )
    |> Enum.map(
      fn ({statement, quads}) ->
        processed_quads =
          quads
          |> Acl.process_quads_for_update( Acl.Config.UserGroups.user_groups, authorization_groups )
          |> elem(1)

        case statement do
          :insert ->
            Updates.QueryAnalyzer.construct_insert_query_from_quads( processed_quads, options )
          :delete ->
            Updates.QueryAnalyzer.construct_delete_query_from_quads( processed_quads, options )
        end end )
  end

  def decode_json_access_groups( json_string ) do
    json_string
    |> Poison.decode!
    |> Enum.map( fn (%{"name" => name, "variables" => variables}) -> {name, variables} end )
  end

  defp encode_json_access_groups( access_groups ) do
    access_groups
    |> Enum.map( fn ({name, variables}) ->
      %{ "name" => name, "variables" => variables }
    end)
    |> Poison.encode!
  end

end
