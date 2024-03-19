defmodule SparqlServer.Router do
  alias SparqlServer.Router.HandlerSupport, as: Support

  @moduledoc """
  The router for the SPARQL endpoint.
  """
  use Plug.Router
  require Logger
  require ALog
  require Poison

  alias SparqlClient.InfoEndpoint

  plug(:match)
  plug(:dispatch)

  def init(args) do
    args
  end

  ################
  ### Routing code

  post "/sparql" do
    {:ok, body, _} = read_body(conn)

    ALog.di(conn, "Received POST connection")
    conn = downcase_request_headers(conn)
    debug_log_request_id(conn)

    {method, query} = get_query_from_post(conn, body) |> ALog.di("Received query")
    handle_query_processing_and_response(query, method, conn)
  end

  get "/sparql" do
    case conn.query_string do
      "" ->
        render_default_page(conn)

      query_string ->
        params = URI.decode_query(query_string)

        ALog.di(conn, "Received GET connection")
        conn = downcase_request_headers(conn)
        debug_log_request_id(conn)

        handle_query_processing_and_response(params["query"], :query, conn)
    end
  end

  get "/running-queries" do
    running_queries = InfoEndpoint.get_running_queries()
    inspect_options = [limit: 100_000, pretty: true, width: 180]

    Logging.EnvLog.inspect(
      running_queries,
      :log_workload_info_requests,
      [{:label, "Currently running queries"} | inspect_options]
    )

    json = running_queries |> Enum.map(fn q -> %{type: "queries", id: q.id, attributes: q} end)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{data: json}))
  end

  get "/processing-queries" do
    processing_queries = InfoEndpoint.get_processing_queries()
    inspect_options = [limit: 100_000, pretty: true, width: 180]

    Logging.EnvLog.inspect(
      processing_queries,
      :log_workload_info_requests,
      [{:label, "Currently processing queries"} | inspect_options]
    )

    json = processing_queries |> Enum.map(fn q -> %{type: "queries", id: q.id, attributes: q} end)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{data: json}))
  end

  get "/recovery-status" do
    last_completed_workload_info =
      SparqlClient.WorkloadInfo.get_state()
      |> Map.get(:last_finished_workload)
      |> Map.update!(:start_time, &DateTime.to_iso8601/1)

    inspect_options = [limit: 100_000, pretty: true, width: 180]

    Logging.EnvLog.inspect(
      last_completed_workload_info,
      :log_workload_info_requests,
      [{:label, "Current recovery status"} | inspect_options]
    )

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(last_completed_workload_info))
  end

  match(_, do: send_resp(conn, 404, "404 error not found"))

  ################
  ### Internal logic

  defp render_default_page(conn) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/ld+json")
    |> send_resp(200, "{
      \"@context\": {
        \"sd\": \"http://www.w3.org/ns/sparql-service-description#\",
        \"rdf\": \"http://www.w3.org/1999/02/22-rdf-syntax-ns#\",
        \"ical:dtstart\": {
          \"@type\": \"xsd:dateTime\"
        }
      },
      \"@id\": \"http://mu.semte.ch/services/mu-authorization\",
      \"rdf:type\": { \"@id\": \"sd:Service\" },
      \"sd:endpoint\": {\"@id\": \"/sparql\"},
      \"sd:supportedLanguage\": [{\"@id\": \"sd:SPARQL11Query\"}, {\"@id\": \"sd:SPARQL11Update\"}],
      \"sd:resultFormat\": {\"@id\": \"http://www.w3.org/ns/formats/SPARQL_Results_JSON\"}
    }")
  end

  defp handle_query_processing_and_response(query, method, conn) do
    qi = InfoEndpoint.start_processing_query(query)

    try do
      Support.handle_query(query, method, conn)
      |> send_sparql_response
    catch
      :exit, {:timeout, call_info} ->
        Logging.EnvLog.inspect(call_info, :errors, label: "Server overload, failed call")
        send_resp(conn, 503, "Processing request took too long")

      :exit, info ->
        Logging.EnvLog.inspect(info, :errors,
          label: "Unknown exit message received when processing query"
        )

        send_resp(conn, 500, "Unknown error occurred when processing query")
    after
      InfoEndpoint.finish_processing_query(qi)
    end
  end

  defp get_query_from_post(conn, body) do
    cond do
      Plug.Conn.get_req_header(conn, "content-type") == ["application/sparql-update"] ->
        {:update, body}
      Plug.Conn.get_req_header(conn, "content-type") == ["application/sparql-query"] ->
        {:any, body}
      true ->
        body_params = URI.decode_query(body)

        cond do
          # apparently this can be both :query as well as :update in practice
          body_params["query"] ->
            {:any, body_params["query"]}

          body_params["update"] ->
            {:update, body_params["update"]}

          true ->
            params =
              conn.query_string
              |> URI.decode_query()

            {:any, params["query"]}
        end
    end
  end

  defp downcase_request_headers(conn) do
    new_request_headers =
      conn
      |> Map.get(:req_headers)
      |> Enum.map(fn {name, val} -> {String.downcase(name), val} end)

    conn
    |> Map.put(:req_headers, new_request_headers)
  end

  defp send_sparql_response({conn, http_status_code, response}) do
    conn
    |> put_resp_content_type("application/sparql-results+json")
    |> send_resp(http_status_code, response)
  end

  ### Allows us to debug log the request id.  Currently doesn't
  ### execute any code.
  defp debug_log_request_id(_conn) do
    # conn
    # |> Plug.Conn.get_req_header( "mu-session-id" )
    # |> List.first
    # |> ALog.di( "session id" )
  end
end
