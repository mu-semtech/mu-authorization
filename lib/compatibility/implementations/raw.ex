defmodule Compat.Implementations.Raw do
  @behaviour Compat.DatabaseAdapter

  @impl Compat.DatabaseAdapter
  def update_query(query), do: query
end
