defmodule SparqlClient do
  require Logger
  require ALog

  @moduledoc """
  A client library that offers the possibility to query a SPARQL endpoint
  """

  @default_query_options [timeout: :infinity]

  def default_endpoint do
    System.get_env("MU_SPARQL_ENDPOINT") || "http://localhost:8890/sparql"
  end

  def query(query, options \\ [])

  def query(query, options) when is_binary(query) do
    options = options ++ @default_query_options

    outgoing_headers = ["Content-Type": "application/x-www-form-urlencoded"]

    outgoing_headers =
      if options[:request] do
        call_id = Plug.Conn.get_req_header(options[:request], "mu-call-id")
        outgoing_headers ++ ["mu-call-id": call_id]
      else
        outgoing_headers
      end

    poison_options = [recv_timeout: options[:timeout]]

    ALog.ii(query, "Sending sparql query to backend")

    Logging.EnvLog.log(:log_outgoing_sparql_queries, "Outgoing SPARQL query: #{query}")

    Logging.EnvLog.inspect(query, :inspect_outgoing_sparql_queries, label: "Outgoing SPARQL query")

    # form parameters
    # headers
    response =
      HTTPoison.post!(
        default_endpoint(),
        [
          "query=" <>
            URI.encode_www_form(query) <>
            "&format=" <> URI.encode_www_form("application/sparql-results+json")
        ],
        outgoing_headers,
        poison_options
      ).body

    Logging.EnvLog.log(:log_outgoing_sparql_query_responses, "Response to sparql query: #{response}")
    Logging.EnvLog.inspect(query, :inspect_outgoing_sparql_query_responses, label: "Response to sparql query:")

    Logging.EnvLog.log(:log_outgoing_sparql_query_roundtrip, "Outgoing sparql query: #{query}\nincoming sparql response #{response}")

    try do
      Poison.decode!(response)
    rescue
      exception ->
        IO.inspect(response, label: "Response received from database")
        # TODO when upgrading elixir, change to reraise
        raise exception
    end
  end

  def execute_parsed(query, options \\ [])

  def execute_parsed(query, options) do
    query
    |> Compat.update_query()
    |> Regen.result()
    |> query(options)
  end

  def extract_results(parsed_response) do
    parsed_response
    |> Map.get("results")
    |> Map.get("bindings")
  end
end
