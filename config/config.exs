# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

defmodule CH do
  def system_boolean(name, default \\ false) do
    case String.downcase(System.get_env(name) || "") do
      "true" -> true
      "yes" -> true
      "1" -> true
      "on" -> true
      "" -> default
      _ -> false
    end
  end

  def database_compatibility(name) do
    (System.get_env(name) || "")
    |> String.downcase()
    |> case do
      "virtuoso" -> Compat.Implementations.Virtuoso
      _ -> Compat.Implementations.Raw
    end
  end

  def system_number(name, default) do
    try do
      (System.get_env(name) || "")
      |> String.to_integer()
    rescue
      ArgumentError -> default
    end
  end

  def system_float(name, default \\ false) do
    try do
      (System.get_env(name) || "")
      |> String.to_float()
    rescue
      ArgumentError -> default
    end
  end
end

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :sparqlex, key: :value
config :"mu-authorization",
  author: :"mu-semtech",
  log_server_configuration: CH.system_boolean("LOG_SERVER_CONFIGURATION"),
  log_outgoing_sparql_queries: CH.system_boolean("LOG_OUTGOING_SPARQL_QUERIES"),
  log_incoming_sparql_queries: CH.system_boolean("LOG_INCOMING_SPARQL_QUERIES"),
  inspect_outgoing_sparql_queries: CH.system_boolean("INSPECT_OUTGOING_SPARQL_QUERIES"),
  inspect_incoming_sparql_queries: CH.system_boolean("INSPECT_INCOMING_SPARQL_QUERIES"),
  log_delta_messages: CH.system_boolean("LOG_DELTA_MESSAGES"),
  log_template_matcher_performance: CH.system_boolean("LOG_TEMPLATE_MATCHER_PERFORMANCE"),
  log_delta_client_communication: CH.system_boolean("LOG_DELTA_CLIENT_COMMUNICATION"),
  log_access_rights: CH.system_boolean("LOG_ACCESS_RIGHTS"),
  inspect_access_rights_processing: CH.system_boolean("INSPECT_ACCESS_RIGHTS_PROCESSING"),
  database_compatibility: CH.database_compatibility("DATABASE_COMPATIBILITY"),
  log_outgoing_sparql_query_responses: CH.system_boolean("LOG_OUTGOING_SPARQL_QUERY_RESPONSES"),
  inspect_outgoing_sparql_query_responses:
    CH.system_boolean("INSPECT_OUTGOING_SPARQL_QUERY_RESPONSES"),
  log_outgoing_sparql_query_roundtrip: CH.system_boolean("LOG_OUTGOING_SPARQL_QUERY_ROUNDTRIP"),
  default_sparql_endpoint: System.get_env("MU_SPARQL_ENDPOINT") || "http://localhost:8890/sparql",
  query_max_processing_time: CH.system_number("QUERY_MAX_PROCESSING_TIME", 120_000),
  query_max_execution_time: CH.system_number("QUERY_MAX_EXECUTION_TIME", 60_000),
  database_recovery_mode_enabled: CH.system_boolean("DATABASE_OVERLOAD_RECOVERY"),
  log_database_recovery_mode_tick: CH.system_boolean("LOG_DATABASE_OVERLOAD_TICK"),
  log_workload_info_requests: CH.system_boolean("LOG_WORKLOAD_INFO_REQUESTS"),
  testing_auth_query_error_rate: CH.system_float("TESTING_AUTH_QUERY_ERROR_RATE"),
  error_on_unwritten_data: CH.system_boolean("ERROR_ON_UNWRITTEN_DATA"),
  errors: CH.system_boolean("LOG_ERRORS", true)

# and access this configuration in your application as:
#
#     Application.get_env(:sparql, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

config :logger,
  compile_time_purge_matching: :debug,
  level: :warn

# config :logger,
#   compile_time_purge_level: :debug,
#   level: :warn

if Mix.env() == :test do
  config :junit_formatter,
    report_dir: "/tmp/repo-example-test-results/exunit"
end

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

import_config "#{Mix.env()}.exs"
