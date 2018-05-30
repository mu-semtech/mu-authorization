alias Acl.Accessibility.ByQuery, as: AccessByQuery

defmodule AccessByQuery do
  defstruct [:vars, :query]

  @moduledoc """

  Represents a constraint that depends on the state of the
  triplestore.  A SPARQL query is executed to determine whether the
  user should have access or not.

  An example SPARQL query could look like

      PREFIX foaf: <http://xmlns.com/foaf/0.1/>
      PREFIX musession: <https://mu.semte.ch/vocabularies/session/>
      PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
      SELECT ?user_uuid
      WHERE {
        <SESSION_ID> musession:account/^foaf:account/mu:uuid ?user_uuid
      }

  In this case, <SESSION_ID> will be replaced by the URI of the
  session of the current user.  The selected variable (?user_uuid)
  could be found multiple times.  A matching graph will be yielded for
  /each/ returned variable, as specified by the 'vars' portion of the
  AccessByQuery specification.  This construction allows yielding
  contents conditionally based on the current state of the
  application.
  """
  defimpl Acl.Accessibility.Protocol do
    @doc """
    TODO: describe docs
    """
    def accessible?( %AccessByQuery{} = access, graph_spec, request ) do
      IO.puts "is this query thing accessible?"
      AccessByQuery.accessible?( access, graph_spec, request )
    end
  end

  def accessible?( %AccessByQuery{ vars: vars, query: query } = access, graph_spec, request ) do
    IO.puts "is this query accessible?"

    query
    |> manipulate_sparql_query( request )
    |> SparqlClient.query
    |> retrieve_access_vars( vars )
    |> extract_results
  end

  def manipulate_sparql_query( query, request ) do
    if get_session_uri(request) do
      query
      |> Parser.parse_query_full
      |> Manipulators.SparqlQuery.replace_iri( "<SESSION_ID>" , "<" <> get_session_uri(request) <> ">" )
      |> Manipulators.SparqlQuery.add_from_graph( "http://mu.semte.ch/authorizations" )
      |> Regen.result
      |> IO.inspect( label: "validation query" )
    else
      IO.puts "No session"
      query
      |> Parser.parse_query_full
      |> Manipulators.SparqlQuery.add_from_graph( "http://mu.semte.ch/authorizations" )
      |> Regen.result
      |> IO.inspect( label: "validation query" )
    end
  end

  def get_session_uri( request ) do
    request
    |> Plug.Conn.get_req_header( "mu-session-id" )
    |> List.first
    |> IO.inspect( label: "session id" )
  end

  def retrieve_access_vars( query_result, vars ) do
    query_result
    |> SparqlClient.extract_results
    |> Enum.map( fn (result) ->
      Enum.map( vars, fn (var) -> Map.get( result, var ) |> Map.get("value") end )
    end )
  end

  def extract_results( [] ) do
    { :fail }
  end
  def extract_results( nested_arr ) do
    {:ok, nested_arr}
  end


end
