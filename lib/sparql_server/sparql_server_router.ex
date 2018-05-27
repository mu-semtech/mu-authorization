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

    query = body_params["query"]

    response = handle_query query, conn

    conn
    |> put_resp_content_type( "application/json" )
    |> send_resp(200, response)
  end

  get "/sparql" do
    params = conn.query_string |> URI.decode_query

    query = params["query"]

    response = handle_query query, conn

    conn
    |> put_resp_content_type( "application/json" )
    |> send_resp(200, response)
  end

  match _, do: send_resp(conn, 404, "404 error not found")

  # TODO for now this method does not apply our access constraints
  defp handle_query(query, conn) do
    parsed_form =
      query
      |> String.trim
      |> Parser.parse_query_full

    new_parsed_forms = if is_select_query( parsed_form ) do
      manipulate_select_query( parsed_form, conn )
    else
      manipulate_update_query( parsed_form, conn )
    end

    new_parsed_forms
    |> IO.inspect
    |> Enum.reduce( nil, fn( elt, _ ) ->
      elt
      |> Regen.result
      |> SparqlClient.query
    end )
    |> Poison.encode!
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

  defp manipulate_select_query( query, _conn ) do
    # TODO: apply Acl.Config.UserGroups to select queries
    query
    |> Manipulators.SparqlQuery.remove_graph_statements
    |> Manipulators.SparqlQuery.remove_from_statements # TODO: check how BaseDecl should be interpreted, possibly also remove that.
    |> Manipulators.Recipes.set_application_graph
    |> (fn (e) -> [e] end).()
  end

  defp manipulate_update_query( query, conn ) do
    # TODO DRY into/from Updates.QueryAnalyzer.insert_quads

    # TODO: Check where the default_graph is used where these options are passed and verify whether this is a sensible name.
    options = %{ default_graph: Updates.QueryAnalyzer.Iri.from_iri_string( "<http://mu.semte.ch/application>", %{} ) }   
    query
    |> Updates.QueryAnalyzer.quads( %{ default_graph:
                                     Updates.QueryAnalyzer.Iri.from_iri_string(
                                       "<http://mu.semte.ch/application>", %{} ) } )
    |> Enum.map(
      fn ({statement, quads}) ->
        processed_quads =
          quads
          |> Acl.process_quads_for_update( Acl.Config.UserGroups.user_groups, conn )
          |> elem(1)

        case statement do
          :insert ->
            Updates.QueryAnalyzer.construct_insert_query_from_quads( processed_quads, options )
          :delete ->
            Updates.QueryAnalyzer.construct_delete_query_from_quads( processed_quads, options )
        end end )
  end

end
