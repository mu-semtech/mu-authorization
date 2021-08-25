defmodule Cache.Deltas do
  alias SparqlServer.Router.AccessGroupSupport, as: AccessGroupSupport
  alias Updates.QueryAnalyzer
  alias Updates.QueryAnalyzer.P, as: QueryAnalyzerProtocol
  alias Updates.QueryAnalyzer.Types.Quad, as: Quad

  require Logger
  require ALog
  use GenServer

  @type cache_logic_key :: :precache | :construct | :ask

  # {effective inserts, effective deletions, all inserts, all deletions}
  defp new_cache, do: {%{}, %{}, %{}, %{}}

  ### GenServer API
  @doc """
    GenServer.init/1 callback
  """
  def init(state) do
    state = state || %{metas: [], cache: new_cache(), index: :os.system_time(:millisecond)}
    {:ok, state}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
    Flush the current state, actually applying the delta's to the triplestore.
  """
  def flush(options) do
    GenServer.call(__MODULE__, {:flush, options})
  end

  # @spec add_deltas(QueryAnalyzer.quad_changes(), cache_logic_key()) :: :ok
  def add_deltas(quad_changes, options, logic, delta_meta \\ []) do
    # TODO
    # :precache ->
    #   GenServer.cast(__MODULE__, {:cache_w_cache, quad_changes})

    GenServer.cast(
      __MODULE__,
      {:cache, logic, quad_changes, Map.new(delta_meta), options}
    )

    # TODO
    # :ask ->
    #   GenServer.cast(__MODULE__, {:cache_w_ask, quad_changes})
  end

  # Reduce :insert and :delete delta's into true and all delta's
  # All delta's have a list of indices. Only one insert can be an actual insert,
  # but multiple delta's can insert the same quad
  #
  # An insert is a true delta if the quad is not yet present in the triplestore
  # If an insert would insert a triple that is marked as true deletion,
  # this deletion and insertion are false.
  defp add_delta_to_state({:insert, quad}, state) do
    cache_type = List.first(state.metas).cache_type
    {true_inserts, true_deletions, all_inserts, all_deletions} = state.cache

    new_cache =
      if CacheType.quad_in_store?(cache_type, quad) do
        if Map.has_key?(true_deletions, quad) do
          # Element in store, but would be deleted
          # Remove true_deletion
          all_inserts = Map.update(all_inserts, quad, [state.index], &[state.index | &1])
          true_deletions = Map.delete(true_deletions, quad)

          {true_inserts, true_deletions, all_inserts, all_deletions}
        else
          all_inserts = Map.update(all_inserts, quad, [state.index], &[state.index | &1])
          {true_inserts, true_deletions, all_inserts, all_deletions}
        end
      else
        # This is important, the quad might be inserted and deleted with a previous delta
        # But that index is more correct than the new index
        index = Enum.min(Map.get(all_inserts, quad, [state.index]))
        true_inserts = Map.put_new(true_inserts, quad, index)
        all_inserts = Map.update(all_inserts, quad, [state.index], &[state.index | &1])

        {true_inserts, true_deletions, all_inserts, all_deletions}
      end

    %{state | cache: new_cache}
  end

  # A deletion is a true deletion if the quad is present in the triplestore
  # If a true insertion would insert this quad, the insert is actually a false insert
  defp add_delta_to_state({:delete, quad}, state) do
    cache_type = List.first(state.metas).cache_type
    {true_inserts, true_deletions, all_inserts, all_deletions} = state.cache

    new_cache =
      if CacheType.quad_in_store?(cache_type, quad) do
        index = Enum.min(Map.get(all_deletions, quad, [state.index]))
        true_deletions = Map.put_new(true_deletions, quad, index)
        all_deletions = Map.update(all_deletions, quad, [state.index], &[state.index | &1])

        {true_inserts, true_deletions, all_inserts, all_deletions}
      else
        if Map.has_key?(true_inserts, quad) do
          # Element not in store, but would be inserted and deleted
          # So both false insert and false deletion
          true_inserts = Map.delete(true_inserts, quad)
          all_deletions = Map.update(all_deletions, quad, [state.index], &[state.index | &1])

          {true_inserts, true_deletions, all_inserts, all_deletions}
        else
          all_deletions = Map.update(all_deletions, quad, [state.index], &[state.index | &1])

          {true_inserts, true_deletions, all_inserts, all_deletions}
        end
      end

    %{state | cache: new_cache}
  end

  defp convert_quad(%Quad{graph: graph, subject: subject, predicate: predicate, object: object}) do
    [g, s, p, o] =
      Enum.map(
        [graph, subject, predicate, object],
        &QueryAnalyzerProtocol.to_sparql_result_value/1
      )

    %{"graph" => g, "subject" => s, "predicate" => p, "object" => o}
  end

  defp delta_update(state) do
    {true_inserts, true_deletions, all_inserts, all_deletions} = state.cache

    merge_f = fn _, one, two -> one ++ two end

    # Merge on index
    inserts =
      Enum.group_by(true_inserts, &elem(&1, 1), &{:effective_insert, convert_quad(elem(&1, 0))})

    deletions =
      Enum.group_by(true_deletions, &elem(&1, 1), &{:effective_delete, convert_quad(elem(&1, 0))})

    all_inserts =
      Enum.flat_map(all_inserts, fn {quad, ids} -> Enum.map(ids, &{quad, &1}) end)
      |> Enum.group_by(&elem(&1, 1), &{:insert, convert_quad(elem(&1, 0))})

    all_deletions =
      Enum.flat_map(all_deletions, fn {quad, ids} -> Enum.map(ids, &{quad, &1}) end)
      |> Enum.group_by(&elem(&1, 1), &{:delete, convert_quad(elem(&1, 0))})

    # Combine all things
    total =
      Map.merge(inserts, deletions, merge_f)
      |> Map.merge(all_inserts, merge_f)
      |> Map.merge(all_deletions, merge_f)

    messages =
      Enum.map(state.metas, fn meta ->
        index = meta.index

        other_meta =
          Map.new()
          |> add_index(index)
          |> add_allowed_groups(meta.delta_meta)
          |> add_origin(meta.delta_meta)
          |> add_trail(meta.delta_meta)

        Map.get(total, index, [])
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Enum.reduce(other_meta, &add_delta/2)
      end)

    %{
      "changeSets" => messages
    }
    |> Poison.encode!()
    |> Delta.Messenger.inform_clients()
  end

  # These might be better suited in seperate file
  defp add_delta({:effective_insert, items}, map) do
    Map.put(map, "effectiveInserts", items)
  end

  defp add_delta({:effective_delete, items}, map) do
    Map.put(map, "effectiveDeletes", items)
  end

  defp add_delta({:insert, items}, map) do
    Map.put(map, "insert", items)
  end

  defp add_delta({:delete, items}, map) do
    Map.put(map, "delete", items)
  end

  defp add_allowed_groups(map, %{authorization_groups: :sudo}) do
    Map.put(map, "allowedGroups", "sudo")
  end

  defp add_allowed_groups(map, %{authorization_groups: groups}) do
    json_access_groups = AccessGroupSupport.encode_json_access_groups(groups)
    Map.put(map, "allowedGroups", json_access_groups)
  end

  defp add_allowed_groups(map, _), do: map

  defp add_trail(map, %{mu_call_id_trail: trail}), do: Map.put(map, "muCallIdTrail", trail)
  defp add_trail(map, _), do: map

  defp add_origin(map, %{origin: origin}), do: Map.put(map, "origin", origin)
  defp add_origin(map, _), do: map

  defp add_index(map, index), do: Map.put(map, "index", index)

  defp do_flush(state, options) do
    {true_inserts, true_deletions, all_inserts, all_deletions} = state.cache

    inserts = Map.keys(true_inserts)

    unless Enum.empty?(inserts) do
      QueryAnalyzer.construct_insert_query_from_quads(inserts, options)
      |> Regen.result()

      QueryAnalyzer.construct_insert_query_from_quads(inserts, options)
      |> SparqlClient.execute_parsed(query_type: :write)
    end

    deletions = Map.keys(true_deletions)

    unless Enum.empty?(deletions) do
      QueryAnalyzer.construct_delete_query_from_quads(deletions, options)
      |> Regen.result()

      QueryAnalyzer.construct_delete_query_from_quads(deletions, options)
      |> SparqlClient.execute_parsed(query_type: :write)
    end

    if not (Enum.empty?(all_inserts) and Enum.empty?(all_deletions)) do
      delta_update(state)
    end

    %{state | cache: new_cache(), metas: []}
  end

  @doc """
    GenServer.handle_call/3 callback
  """
  def handle_call({:flush, options}, _from, state) do
    new_state = do_flush(state, options)

    {:reply, :ok, new_state}
  end

  # delta_meta: mu_call_id_trail, authorization_groups, origin
  def handle_cast({:cache, type, quads, delta_meta, options}, state) do
    timeout_sessions = Application.get_env(:"mu-authorization", :quad_change_cache_session)

    current_timeout =
      Map.get(state, :ref, nil)
      |> IO.inspect(label: "current timeout")

    state =
      if is_nil(current_timeout) or timeout_sessions do
        if not is_nil(current_timeout) do
          Process.cancel_timer(current_timeout)
        end

        timeout_duration =
          Application.get_env(:"mu-authorization", :quad_change_cache_timeout)
          |> IO.inspect(label: "timeout duration")

        ref = Process.send_after(self(), {:timeout, options}, timeout_duration)

        Map.put(state, :ref, ref)
      else
        state
      end

    deltas = Enum.flat_map(quads, fn {type, qs} -> Enum.map(qs, &{type, &1}) end)
    quads = Enum.map(deltas, &elem(&1, 1))

    # Calculate meta data
    cache_type = CacheType.create_cache_type(type, quads)

    # Add metadata to state
    meta = %{
      cache_type: cache_type,
      delta_meta: delta_meta,
      index: state.index + 1
    }

    state_with_meta = %{state | metas: [meta | state.metas], index: state.index + 1}

    # Reduce with add_delta_to_state
    new_state = Enum.reduce(deltas, state_with_meta, &add_delta_to_state/2)

    {:noreply, new_state}
  end

  def handle_info({:timeout, options}, state) do
    IO.puts("Timeout timeout!")
    new_state = do_flush(state, options)

    {:noreply, new_state}
  end
end

# You like kinda want an 'instant' struct but that changes more then `quad_in_store`
