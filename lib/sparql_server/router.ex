alias SparqlServer.Router.HandlerSupport, as: Support

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

  defp process_request_headers( conn ) do
    new_request_headers =
      conn
      |> Map.get(:req_headers)
      |> Enum.map( fn {name, val} -> { String.downcase( name ), val } end )

    conn
    |> Map.put( :req_headers, new_request_headers )
  end

  # TODO these methods are still very similar, I need to spent time
  #      to get the proper abstractions out
  post "/sparql" do
    {:ok, body, _} = read_body(conn)

    ALog.di conn, "Received POST connection"
    conn = process_request_headers( conn )

    { method, query } = get_query_from_post( conn, body ) |> ALog.di( "Received query" )

    { conn, response } = Support.handle_query query, method, conn

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

    { conn, response } = Support.handle_query query, :query, conn

    ALog.di conn.req_headers, "Request headers"
    ALog.di conn.resp_headers, "Response headers"
    ALog.di response, "Response content"

    conn
    # |> put_resp_content_type( "application/json" )
    |> put_resp_content_type( "application/sparql-results+json" )
    |> send_resp(200, response)
  end

  match _, do: send_resp(conn, 404, "404 error not found")

end
