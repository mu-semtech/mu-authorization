# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

defmodule CH do
  def system_boolean( name ) do
    case String.downcase( System.get_env( name ) || "" ) do
      "true" -> true
      "yes" -> true
      "1" -> true
      "on" -> true
      _ -> false
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
  log_outgoing_sparql_queries: CH.system_boolean("LOG_OUTGOING_SPARQL_QUERIES"),
  log_incoming_sparql_queries: CH.system_boolean("LOG_INCOMING_SPARQL_QUERIES"),
  inspect_outgoing_sparql_queries: CH.system_boolean("INSPECT_OUTGOING_SPARQL_QUERIES"),
  inspect_incoming_sparql_queries: CH.system_boolean("INSPECT_INCOMING_SPARQL_QUERIES"),
  log_delta_messages: CH.system_boolean("LOG_DELTA_MESSAGES"),
  log_template_matcher_performance: CH.system_boolean("LOG_TEMPLATE_MATCHER_PERFORMANCE"),
  log_delta_client_communication: CH.system_boolean("LOG_DELTA_CLIENT_COMMUNICATION"),
  log_access_rights: CH.system_boolean("LOG_ACCESS_RIGHTS"),
  inspect_access_rights_processing: CH.system_boolean("INSPECT_ACCESS_RIGHTS_PROCESSING")

# and access this configuration in your application as:
#
#     Application.get_env(:sparql, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# config :logger,
#   compile_time_purge_level: :debug,
#   level: :info

config :logger,
  compile_time_purge_level: :debug,
  level: :warn

if Mix.env == :test do
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

import_config "#{Mix.env}.exs"
