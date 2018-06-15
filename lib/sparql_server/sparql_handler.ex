 defmodule SPARQLServer.SPARQLHandler do
  @moduledoc """
  # SPARQLServer.SPARQLHandler
  A generic queue for handling SPARQL queries. It has support for 3 SPARQL lifecycle
  hooks:
  * add-query: this hook will be called when a query gets added
  * pick-query: this hook gets called every time the next query needs to picked for processing
  * process-query: this hook gets called to process a query

  # Hooks
  ## add-query
  The add-query function gets the current query-queue as argument and the query to add and is expected to returned the next current query-queue.

  ## pick-query
  The pick-query function gets 1 argument, the current queue. It then returns a 3 tuple that holds the selection state, the next current query-queue and the picked query. The selection states can be :continue or :wait.
  For instance suppose you want the query queue to hold after an update query got selected then the :wait atom is returned as start of the 3-tuple and no queries will be handled until all current queries are taken care of.wait). Ex:
  ```
  iex> queue = [query1, query2]
  iex> pick_query(queue)
  {:continue, [query2], query1}
  ```

  ## handle-query
  takes a query and handles it. It then returns a tuple {:action, query} where query is the query that was just handled and :action can be either :stop or :next. :stop will stop this query from further propagating through the system, :next will pass it on to the next handler in our setup.

  # Configuration
  The handle query configuration holds the following properties for a single GenServer:
  * add_query the function that gets called when a query is added
  * pick_query the function that is called to pick a next query to process
  * handle_query the function that handles a query
  * next the next genserver handler process that will take this query
  * current_queries the queries that this system is currently handling
  * current_action the current 'query' state (can be :continue or :wait)
  * current_queue the queue of queries that are waiting to be processed
  * original_process the process to which the results of this flow needs to be returned to
  """
  use GenServer

  def init(config) do
    {:ok, config}
  end

  def handle_cast({:"add-query", query}, config) do
    current_queue = config.add_query.(config.current_queue, query)
    new_config = %{
      add_query: config.add_query,
      pick_query: config.pick_query,
      process_query: config.process_query,
      next: config.next,
      current_queries: config.current_queries,
      current_action: config.current_action,
      current_queue: current_queue,
      original_process: config.original_process
    }
    GenServer.cast(self, :"pick-query")
    {:noreply, new_config}
  end

  # if the current_queue is empty then we don't need to pick or process anything
  def handle_cast(:"pick-query", %{add_query: add_query,
                                   pick_query: pick_query,
                                   process_query: process_query,
                                   next: next,
                                   current_queries: current_queries,
                                   current_action: current_action,
                                   current_queue: [],
                                   original_process: :none}) do
    {:noreply, %{add_query: add_query,
                 pick_query: pick_query,
                 process_query: process_query,
                 next: next,
                 current_queries: current_queries,
                 current_action: current_action,
                 current_queue: [],
                 original_process: :none}}
  end

  def handle_cast(:"pick-query", %{add_query: add_query,
                                   pick_query: pick_query,
                                   process_query: process_query,
                                   next: next,
                                   current_queries: current_queries,
                                   current_action: :wait,
                                   current_queue: current_queue,
                                   original_process: :none}) do
    {:noreply, %{add_query: add_query,
                 pick_query: pick_query,
                 process_query: process_query,
                 next: next,
                 current_queries: current_queries,
                 current_action: :wait,
                 current_queue: current_queue,
                 original_process: :none}}
  end

  def handle_cast(:"pick-query", config) do
    {action, new_array, query} = config.pick_query.(config.current_queue)
    GenServer.cast(self, {:"process-query", query})
    cond do
      action == :continue ->
        GenServer.cast(self, :"pick-query")
      action == :wait ->
        IO.puts("waiting...")
    end
    {:noreply, %{add_query: config.add_query,
                 pick_query: config.pick_query,
                 process_query: config.process_query,
                 next: config.next,
                 current_queries: [query | config.current_queries],
                 current_action: action,
                 current_queue: new_array,
                 original_process: :none}}
  end

  def handle_cast({:"process-query", query}, config) do
    {action, next, query} = config.process_query.(query, config.next)
    cond do
      action == :next ->
        GenServer.cast(config.next, {:"add-query", query})
      action == :stop ->
        IO.puts "stop called"
    end
    GenServer.cast(self, :"pick-query")
    {:noreply, %{add_query: config.add_query,
                 pick_query: config.pick_query,
                 process_query: config.process_query,
                 next: config.next,
                 current_queries: remove_first_occurence(config.current_queries, query),
                 current_action: :continue,
                 current_queue: config.current_queue,
                 original_process: config.original_process}}
  end

  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end

  def handle_call(:current_queue, _from, config) do
    {:reply, config.current_queue, config}
  end

  # helper function that allows me to remove the first occurence of an item
  # from a list
  def remove_first_occurence([], _) do
    []
  end

  def remove_first_occurence([item | tail], item) do
    tail
  end

  def remove_first_occurence([head | tail], item) do
    [head | remove_first_occurence(tail, item)]
  end
end
