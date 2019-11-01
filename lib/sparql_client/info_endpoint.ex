defmodule SparqlClient.InfoEndpoint do
  require Logger
  require ALog
  use GenServer

  alias SparqlClient.QueryInfo

  defstruct running_queries: [],
            processing_queries: []

  @type t :: %SparqlClient.InfoEndpoint{
          running_queries: [SparqlClient.QueryInfo.t()],
          processing_queries: [SparqlClient.QueryInfo.t()]
        }

  @typep mapper(type) :: (type -> type)

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  @spec start_query(String.t()) :: QueryInfo.t()
  def start_query(query) do
    qi = QueryInfo.new(query, new_id())
    GenServer.cast(__MODULE__, {:start_query, qi})
    qi
  end

  @spec end_query(QueryInfo.t()) :: :ok
  def end_query(qi) do
    GenServer.cast(__MODULE__, {:end_query, qi})
  end

  @spec retry_query(QueryInfo.t()) :: QueryInfo.t()
  def retry_query(qi) do
    GenServer.call(__MODULE__, {:retry_query, qi})
  end

  @spec start_processing_query(String.t()) :: QueryInfo.t()
  def start_processing_query(query) do
    qi = QueryInfo.new(query, new_id())
    GenServer.cast(__MODULE__, {:start_processing_query, qi})
    qi
  end

  @spec new_id() :: integer
  defp new_id() do
    Support.Id.new()
  end

  @spec finish_processing_query(QueryInfo.t()) :: :ok
  def finish_processing_query(qi) do
    GenServer.cast(__MODULE__, {:finish_processing_query, qi})
  end

  @spec get_running_queries() :: [QueryInfo.t()]
  def get_running_queries() do
    queries = GenServer.call(__MODULE__, {:get_running_queries})

    queries
    |> Enum.sort_by(&QueryInfo.launched_at/1)
  end

  @spec get_processing_queries() :: [QueryInfo.t()]
  def get_processing_queries() do
    queries = GenServer.call(__MODULE__, {:get_processing_queries})

    queries
    |> Enum.sort_by(&QueryInfo.launched_at/1)
  end

  @impl true
  def handle_cast({:start_query, qi}, state) do
    {:noreply, add_query_info(state, qi)}
  end

  @impl true
  def handle_cast({:end_query, qi}, state) do
    {:noreply, remove_query_info(state, qi)}
  end

  @impl true
  def handle_cast({:start_processing_query, qi}, state) do
    {:noreply, add_processing_query(state, qi)}
  end

  @impl true
  def handle_cast({:finish_processing_query, qi}, state) do
    {:noreply, remove_processing_query(state, qi)}
  end

  @impl true
  def handle_call({:retry_query, qi}, _from, state) do
    new_qi = QueryInfo.increase_retry_count(qi)

    new_state =
      state
      |> remove_query_info(qi)
      |> add_query_info(new_qi)

    {:reply, new_qi, new_state}
  end

  @impl true
  def handle_call({:get_running_queries}, _from, state) do
    # Returns the running queries map, to be sorted by the consuming entity.

    {:reply, state.running_queries, state}
  end

  @impl true
  def handle_call({:get_processing_queries}, _from, state) do
    # Returns the running queries map, to be sorted by the consuming entity.

    {:reply, state.processing_queries, state}
  end

  @spec add_query_info(t(), QueryInfo.t()) :: t()
  defp add_query_info(state, qi) do
    update_running_queries(state, fn queries ->
      [qi | queries]
    end)
  end

  @spec remove_query_info(t(), QueryInfo.t()) :: t()
  defp remove_query_info(state, qi) do
    update_running_queries(state, fn queries ->
      queries
      |> Enum.reject(fn qi_in_state ->
        qi.id == qi_in_state.id
      end)
    end)
  end

  @spec update_running_queries(t(), mapper(map)) :: t()
  defp update_running_queries(state, functor) do
    running_queries =
      state.running_queries
      |> functor.()

    Map.put(state, :running_queries, running_queries)
  end

  @spec add_processing_query(t(), QueryInfo.t()) :: t()
  defp add_processing_query(state, qi) do
    update_processing_queries(state, fn queries ->
      [qi | queries]
    end)
  end

  @spec remove_processing_query(t(), QueryInfo.t()) :: t()
  defp remove_processing_query(state, qi) do
    update_processing_queries(state, fn queries ->
      queries
      |> Enum.reject(fn qi_in_state ->
        qi.id == qi_in_state.id
      end)
    end)
  end

  @spec update_processing_queries(t(), mapper([QueryInfo.t()])) :: t()
  defp update_processing_queries(state, functor) do
    processing_queries =
      state.processing_queries
      |> functor.()

    Map.put(state, :processing_queries, processing_queries)
  end
end
