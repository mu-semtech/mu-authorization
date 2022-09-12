defmodule SparqlClient.QueryInfo do
  @moduledoc """
  Information about a single query run.
  """

  defstruct [{:query, nil}, {:launched_at, nil}, {:retries, 0}, :id]

  @type id :: any()

  @type t :: %SparqlClient.QueryInfo{
          query: String.t(),
          launched_at: Elixir.DateTime.t(),
          retries: integer(),
          id: id()
        }

  @doc """
  Creates a new info object for a query.
  """
  @spec new(String.t(), id()) :: t()
  def new(query, id) do
    %__MODULE__{query: query, launched_at: DateTime.utc_now(), id: id}
  end

  @spec increase_retry_count(t()) :: t()
  def increase_retry_count(%__MODULE__{} = qi) do
    %{qi | retries: qi.retries + 1}
  end

  @spec launched_at(t()) :: DateTime.t()
  def launched_at(%__MODULE__{} = qi) do
    qi.launched_at
  end
end
