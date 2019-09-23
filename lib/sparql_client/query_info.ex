defmodule SparqlClient.QueryInfo do
  @moduledoc """
  Information about a single query run.
  """

  defstruct query: nil, launched_at: nil, retries: 0

  @type t :: %SparqlClient.QueryInfo{query: String.t(), launched_at: any(), retries: integer()}

  @doc """
  Creates a new info object for a query.
  """
  @spec new(String.t()) :: t()
  def new(query) do
    %__MODULE__{query: query, launched_at: DateTime.utc_now()}
  end

  @spec increase_retry_count(t()) :: t()
  def increase_retry_count(qi = %__MODULE__{}) do
    %{ qi | retries: qi.retries + 1 }
  end

  @spec launched_at(t()) :: DateTime.t()
  def launched_at(qi = %__MODULE__{}) do
    qi.launched_at
  end
end
