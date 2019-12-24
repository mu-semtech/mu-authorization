defmodule SparqlClient do
  require Logger
  require ALog

  alias SparqlClient.InfoEndpoint
  alias SparqlClient.WorkloadInfo

  @moduledoc """
  A client library that offers the possibility to query a SPARQL endpoint
  """

  @max_retries 10

  @type query_types :: :read | :write | :read_for_write
  @type query_string :: String.t()
  @type parsed_query_response :: Poison.Parser.t() | Poison.no_return()

  @spec query(query_string, query_type: query_types, request: Plug.Conn.t()) ::
          parsed_query_response
  def query(query, options) when is_binary(query) do
    query_max_execution_time = Application.get_env(:"mu-authorization", :query_max_execution_time)

    options = options ++ [timeout: query_max_execution_time]

    outgoing_headers = ["Content-Type": "application/x-www-form-urlencoded"]

    outgoing_headers =
      if options[:request] do
        call_id = Plug.Conn.get_req_header(options[:request], "mu-call-id")
        outgoing_headers ++ ["mu-call-id": call_id]
      else
        outgoing_headers
      end

    # poison_options = [recv_timeout: options[:timeout]]

    ALog.ii(query, "Sending sparql query to backend")

    Logging.EnvLog.log(:log_outgoing_sparql_queries, "Outgoing SPARQL query: #{query}")

    Logging.EnvLog.inspect(query, :inspect_outgoing_sparql_queries, label: "Outgoing SPARQL query")

    query_info = InfoEndpoint.start_query(query)

    do_execute_query({query, query_info, outgoing_headers, options, options[:query_type]})
  end

  @spec do_execute_query(
          {String.t(), SparqlClient.QueryInfo.t(), Keyword.t(), Keyword.t(), query_types}
        ) :: parsed_query_response
  defp do_execute_query(query_spec), do: do_execute_query(query_spec, @max_retries)

  defp do_execute_query({query, query_info, _, _, _}, 0) do
    Logger.error("Failed to execute query #{@max_retries} times #{query}")
    InfoEndpoint.end_query(query_info)
    raise "Backend query retry limit reached"
  end

  defp do_execute_query(
         {query, query_info, outgoing_headers, options, query_type},
         retries
       ) do
    timeout = query_timeout_for_call(retries)

    if timeout > 0 do
      Process.sleep(timeout)
    end

    WorkloadInfo.timeout(query_type)

    if Support.JobCancellation.cancelled?() do
      WorkloadInfo.report_cancellation(query_type)
      throw({:job_cancelled})
    end

    try do
      query_options = options ++ [headers: outgoing_headers]

      case Compat.perform_query(query, query_options) do
        {:fail} ->
          raise "Failed to execute query"

        {:incomplete, _} ->
          # TODO: REMOVE DUPLICATION FROM RESCUE BELOW
          Logger.warn(
            "Failed to answer query #{query} on database within time (try #{
              @max_retries - retries
            })"
          )

          query_info = InfoEndpoint.retry_query(query_info)
          WorkloadInfo.report_timeout(query_type)

          do_execute_query(
            {query, query_info, outgoing_headers, options, query_type},
            retries - 1
          )

        {:ok, response} ->
          Logging.EnvLog.log(
            :log_outgoing_sparql_query_responses,
            "Response to sparql query: #{response}"
          )

          Logging.EnvLog.inspect(query, :inspect_outgoing_sparql_query_responses,
            label: "Response to sparql query:"
          )

          Logging.EnvLog.log(
            :log_outgoing_sparql_query_roundtrip,
            "Outgoing sparql query: #{query}\nincoming sparql response #{response}"
          )

          try do
            decoded_result = Poison.decode!(response)
            WorkloadInfo.report_success(query_type)
            InfoEndpoint.end_query(query_info)
            decoded_result
          rescue
            exception ->
              Logger.warn("Failed to decode response from database")
              IO.inspect(response, label: "Response which could not be decoded")
              # TODO when upgrading elixir, change to reraise
              raise exception
          end
      end
    rescue
      exception ->
        Logger.warn(
          "Failed to execute query #{query} on database (try #{@max_retries - retries})"
        )

        IO.inspect(exception, label: "Exception thrown when executing query")
        query_info = InfoEndpoint.retry_query(query_info)
        # TODO: in the future, we may detect that a failure was
        # actually a timeout, in which case this report needs to be
        # updated.
        WorkloadInfo.report_failure(query_type)

        do_execute_query(
          {query, query_info, outgoing_headers, options, query_type},
          retries - 1
        )
    end
  end

  defp query_timeout_for_call(10), do: 0
  defp query_timeout_for_call(9), do: 10
  defp query_timeout_for_call(8), do: 25
  defp query_timeout_for_call(7), do: 100
  defp query_timeout_for_call(6), do: 250
  defp query_timeout_for_call(5), do: 500
  defp query_timeout_for_call(4), do: 1_000
  defp query_timeout_for_call(3), do: 3_000
  defp query_timeout_for_call(2), do: 8_000
  defp query_timeout_for_call(1), do: 20_000

  @spec execute_parsed(any, query_type: query_types, request: Plug.Conn.t()) :: any
  def execute_parsed(query, options) do
    query
    |> Compat.update_query()
    |> Regen.result()
    |> query(options)
  end

  @doc """
  Converts the raw response into a structured key-based response with easier accessors.
  """
  @spec response(parsed_query_response) :: SparqlClient.QueryResponse.t()
  def response(response), do: SparqlClient.QueryResponse.from_parsed_response(response)

  @doc """
  Extracts the results (results.bindings) from the response.
  """
  def extract_results(%SparqlClient.QueryResponse{} = response) do
    response.results.bindings
  end

  def extract_results(parsed_response) do
    parsed_response
    |> Map.get("results")
    |> Map.get("bindings")
  end
end
