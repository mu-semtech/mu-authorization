defmodule SPARQLServer.Router do
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
  post "/" do
    {:ok, body_params_encoded, _} = read_body(conn)

    body_params = body_params_encoded |> URI.decode_query

    query = body_params["query"]

    response = handle_query query

    send_resp(conn, 200, response)
  end

  get "/" do
    params = conn.query_string |> URI.decode_query

    query = params["query"]

    response = handle_query query
    send_resp(conn, 200, response)
  end

  match _, do: send_resp(conn, 404, "404 error not found")

  # TODO for now this method does not hook into our query parser
  defp handle_query(query) do
    query
    |> SPARQLClient.query
    |> Poison.encode!
  end
end
