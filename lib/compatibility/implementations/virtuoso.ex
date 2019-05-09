defmodule Compat.Implementations.Virtuoso do
  @behaviour Compat.DatabaseAdapter

  @impl Compat.DatabaseAdapter
  def update_query( query ) do
    query
    |> Compat.Modifiers.UpdateDataToUpdateWhere.manipulate
  end
end
