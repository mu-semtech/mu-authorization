defmodule Compat.DatabaseAdapter do
  @callback update_query(query :: InterpreterTerms.query()) :: InterpreterTerms.query()
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
end
