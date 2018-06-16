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

    # Here we want to start the GenServers that will be
    # the queuing mechanism for our queries. This will be
    # preserved as state with Agents.
    result = SPARQLServer.SPARQLHandlerConfiguration.get_config |> start_gen_servers
    Agent.start_link(fn -> result end, name: Config)
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

  defp augment_handler_config(handler_config, nil) do
    %{
      name: handler_config.name,
      add_query: handler_config.add_query,
      pick_query: handler_config.pick_query,
      process_query: handler_config.process_query,
      next: :none,
      current_queries: [],
      current_queue: [],
      current_action: :continue,
      original_process: :none
    }
  end

  defp augment_handler_config(handler_config, next) do
    %{
      name: handler_config.name,
      add_query: handler_config.add_query,
      pick_query: handler_config.pick_query,
      process_query: handler_config.process_query,
      next: next.name,
      current_queries: [],
      current_queue: [],
      current_action: :continue,
      original_process: :none
    }
  end

  defp do_start_gen_server(handler_config) do
    IO.puts "starting server"
    IO.puts handler_config.name
    {:ok, handler} = GenServer.start(SPARQLServer.SPARQLHandler, handler_config, name: handler_config.name)
    handler
  end

  defp do_start_gen_servers(handler_configurations) do
    handler_configurations
    |> Enum.map(fn (x) -> do_start_gen_server(x) end)
  end

  # this method first prepares the configuration passed by adding the
  # next process and all the default variables to it.
  defp start_gen_servers(handler_config) do
    first = handler_config |> (Enum.at 0)
    configs = 1..Enum.count(handler_config)
    |> Enum.map(fn (x) ->
      augment_handler_config(Enum.at(handler_config, x-1), Enum.at(handler_config, x))
    end)
    handlers = do_start_gen_servers(configs)

    # the we return a hash that wraps this info
    %{
      first: first.name,
      configs: configs,
      handlers: handlers
    }
  end

  # TODO for now this method does not hook into our query parser
  defp handle_query(query) do
    # query
    # |> SPARQLClient.query
    # |> Poison.encode!

    # the initial config is kept in an Agent so we need to extract it
    config = Agent.get(Config, fn config -> config end)

    # then we add it to the first GenServer in the array
    GenServer.cast(config.first, {:"add-query", {self(), query}})

    receive do
      msg ->
        IO.puts "received message"
        IO.puts msg
        msg
    end
  end
end
