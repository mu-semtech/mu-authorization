defmodule SparqlClient do
  require Logger
  require ALog

  @moduledoc """
  A client library that offers the possibility to query a SPARQL endpoint
  """

  def default_endpoint do
    System.get_env("MU_SPARQL_ENDPOINT") || "http://localhost:8890/sparql"
  end

  def query(query, endpoint \\ default_endpoint())

  def query(query, endpoint) when is_binary(query) do
    options = [recv_timeout: 50000]

    ALog.ii(query, "Sending sparql query to backend")

    Logging.EnvLog.log(:log_outgoing_sparql_queries, "Outgoing SPARQL query: #{query}")

    Logging.EnvLog.inspect(query, :inspect_outgoing_sparql_queries, label: "Outgoing SPARQL query")

    # form parameters
    # headers
    response =
      HTTPoison.post!(
        endpoint,
        [
          "query=" <>
            URI.encode_www_form(query) <>
            "&format=" <> URI.encode_www_form("application/sparql-results+json")
        ],
        ["Content-Type": "application/x-www-form-urlencoded"],
        options
      ).body

    try do
      Poison.decode!(response)
    rescue
      exception ->
        IO.inspect(response, label: "Response received from database")
        raise exception # TODO when upgrading elixir, change to reraise
    end
  end

  def execute_parsed(query, endpoint \\ default_endpoint())

  def execute_parsed(query, endpoint) do
    query
    |> Compat.update_query()
    |> Regen.result()
    |> query(endpoint)
  end

  def extract_results(parsed_response) do
    parsed_response
    |> Map.get("results")
    |> Map.get("bindings")
  end
end
