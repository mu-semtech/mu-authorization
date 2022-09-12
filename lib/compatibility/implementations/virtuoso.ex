defmodule Compat.Implementations.Virtuoso do
  @behaviour Compat.DatabaseAdapter

  @impl Compat.DatabaseAdapter
  def update_query(query) do
    query
    |> Compat.Modifiers.MergeGraphsForUpdateData.manipulate()

    # |> Compat.Modifiers.UpdateDataToUpdateWhere.manipulate()
  end

  @impl Compat.DatabaseAdapter
  def perform_query(query, options) do
    try do
      # Enable the following line to pretend the database is down:
      # - raise "No sending query, pretending database is down"

      timeout = options[:timeout]

      poison_options =
        if timeout do
          [recv_timeout: timeout]
        else
          []
        end

      endpoint = Application.get_env(:"mu-authorization", :default_sparql_endpoint)

      call_url =
        if timeout && timeout > 1000 do
          endpoint <> "?timeout=#{timeout}"
        else
          endpoint
        end

      poisonResponse =
        HTTPoison.post!(
          call_url,
          [
            "query=" <>
              URI.encode_www_form(query) <>
              "&format=" <> URI.encode_www_form("application/sparql-results+json")
          ],
          options[:headers],
          poison_options
        )

      response = poisonResponse.body

      if Enum.any?(poisonResponse.headers, &match?({"X-Exec-Milliseconds", _}, &1)) do
        {:incomplete, response}
      else
        {:ok, response}
      end
    rescue
      exception ->
        Logging.EnvLog.puts(:error, "Failed to execute query")
        Logging.EnvLog.inspect(exception, :error, label: "Exception")
        Logging.EnvLog.puts(:error, Exception.format_stacktrace())
        {:fail}
    end
  end
end
