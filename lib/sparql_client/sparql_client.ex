defmodule SparqlClient do
  require Logger
  require ALog

  @moduledoc """
  A client library that offers the possibility to query a SPARQL endpoint
  """

  def default_endpoint do
    System.get_env("MU_SPARQL_ENDPOINT") || "http://localhost:8890/sparql"
  end

  def query(query, endpoint\\default_endpoint()) do
    options = [recv_timeout: 50000]

    ALog.ii( query, "Sending sparql query to backend" )

    Logging.EnvLog.log( :log_outgoing_sparql_queries, "Outgoing SPARQL query: #{query}" )
    Logging.EnvLog.inspect( query, :inspect_outgoing_sparql_queries, label: "Outgoing SPARQL query" )

    HTTPoison.post!(
      endpoint,
      # form parameters
      ["query=" <> URI.encode_www_form(query)
       <> "&format=" <> URI.encode_www_form("application/sparql-results+json")],
      # headers
      ["Content-Type": "application/x-www-form-urlencoded"],
      options)
    .body
    |> ALog.ii( "Raw query response" )
    |> Poison.decode!
  end

  def extract_results( parsed_response ) do
    parsed_response
    |> Map.get("results")
    |> Map.get("bindings")
  end
end
