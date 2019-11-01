defmodule Support.Id do
  use GenServer

  @spec new() :: integer()
  @doc """
  Yields a new unique identifier.
  """
  def new() do
    GenServer.call( __MODULE__, :next)
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, 0}
  end

  @impl true
  def handle_call( :next, _from, index ) do
    next = index + 1
    {:reply, next, next}     
  end
end
