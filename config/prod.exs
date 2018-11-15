use Mix.Config

config :"mu-authorization",
  sparql_port: 8890

config :logger,
  compile_time_purge_level: :info,
  level: :warn
