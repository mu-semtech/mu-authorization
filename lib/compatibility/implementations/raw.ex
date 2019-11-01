defmodule Compat.Implementations.Raw do
  @behaviour Compat.DatabaseAdapter

  @impl Compat.DatabaseAdapter
  def update_query(query), do: query

  @impl Compat.DatabaseAdapter
  def perform_query(query, options) do
    SparqlClient.Connection.generic_perform(query, options)
  end
end
