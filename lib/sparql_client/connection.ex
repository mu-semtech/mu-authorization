defmodule SparqlClient.Connection do
  @moduledoc """
  Provides typechecking and generic methods for executing calls
  against the database.  This is mainly intended for database layers.
  See the SparqlClient module for executing queries in a consistent
  manner.
  """

  @type options :: [timeout: number, headers: HTTPoison.headers()]
  @type query_response :: {:ok, String.t()} | {:incomplete, String.t()} | {:fail}

  @spec generic_perform(SparqlClient.query_string(), options) ::
          query_response
  @doc """
  Generic implementation of the perform-query method.  This approach
  can be used when no database specific logic is to be implemented.
  """
  def generic_perform(query, options) do
    try do
      # Enable the following line to pretend the database is down:
      # - raise "No sending query, pretending database is down"

      poison_options = [recv_timeout: options[:timeout]]

      poisonResponse =
        HTTPoison.post!(
          Application.get_env(:"mu-authorization", :default_sparql_endpoint),
          [
            "query=" <>
              URI.encode_www_form(query) <>
              "&format=" <> URI.encode_www_form("application/sparql-results+json")
          ],
          options[:headers],
          poison_options
        )

      {:ok, poisonResponse.body}
    rescue
      _exception ->
        {:fail}
    end
  end
end
