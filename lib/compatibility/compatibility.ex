defmodule Compat.DatabaseAdapter do
  @callback update_query(query :: InterpreterTerms.query()) :: InterpreterTerms.query()

  @callback perform_query(SparqlClient.query_string(), SparqlClient.Connection.options()) ::
              SparqlClient.Connection.query_response()
end

defmodule Compat.QueryManipulator do
  @callback manipulate(query :: InterpreterTerms.query()) :: InterpreterTerms.query()
end

defmodule Compat do
  @behaviour Compat.DatabaseAdapter

  def layer do
    Application.get_env(:"mu-authorization", :database_compatibility)
  end

  @impl Compat.DatabaseAdapter
  def update_query(query), do: layer().update_query(query)

  @impl Compat.DatabaseAdapter
  def perform_query(query, options), do: layer().perform_query(query, options)
end
