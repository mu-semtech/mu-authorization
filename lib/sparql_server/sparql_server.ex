defmodule SparqlServer do
  @moduledoc """
  A proxy server that will behave as a SPARQL endpoint
  """
  use Application
  require Logger

  def start(_type, _args) do
    port = Application.get_env(:"mu-authorization", :"sparql-port", 8890)

    children = [
      {Plug.Adapters.Cowboy2, scheme: :http, plug: SparqlServer.Router, options: [port: port]}
    ]

    Logger.info "SPARQL Endpoint started on " <> to_string(port)

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
