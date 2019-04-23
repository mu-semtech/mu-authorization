defmodule SparqlServer do
  @moduledoc """
  A proxy server that will behave as a SPARQL endpoint
  """
  use Application
  require Logger

  def start(_type, _args) do
    public_port_env = System.get_env("SPARQL_PORT") &&
      elem( Integer.parse( System.get_env("SPARQL_PORT") ), 0 )
    port = public_port_env || Application.get_env(:"mu-authorization", :sparql_port)

    Logging.EnvLog.inspect( port, :log_server_configuration, label: "server setup, sparql port" )
    Logging.EnvLog.inspect( Acl.UserGroups.Config.user_groups, :log_server_configuration, label: "server setup, user groups" )
    Logging.EnvLog.inspect( Delta.Config.targets, :log_server_configuration, label: "server setup, delta targets" )

    children = [
      {Cache.Types,%{}},
      {EbnfParser.Sparql,nil},
      {Interpreter.CachedInterpreter,nil},
      {Interpreter.Diff.Store.Storage,nil},
      {Interpreter.Diff.Store.Manipulator,nil},
      {Plug.Adapters.Cowboy2, scheme: :http, plug: SparqlServer.Router, options: [port: port]},
      :poolboy.child_spec(:worker, [{:name, {:local, :worker}},{:worker_module, SparqlServer.Router.Handler.Worker},{:size, 20},{:max_overflow, 10},{:strategy,:lifo}])
    ]

    Logger.info "SPARQL Endpoint started on #{port}"

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
