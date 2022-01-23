defmodule SparqlClient.WorkloadInfo do
  use GenServer

  alias SparqlClient.WorkloadInfo, as: Workload

  defstruct running_pid_map: %{read: [], read_for_write: [], write: []},
            waiting_from_map: %{read: [], read_for_write: [], write: []},
            running_count: 0,
            recovery_mode: false,
            last_interval_failure_count: 0,
            last_interval_success_count: 0,
            database_failure_load: 0,
            last_finished_workload: nil,
            start_time: DateTime.utc_now()

  use Accessible

  @recovery_max %{write: 5, read_for_write: 5, read: 10}

  @non_recovery_max_running 50

  @failure_load_recovery_score 0.2
  @failure_load_min_failures 3

  @clocktick_interval 5000

  @initial_clocktick_interval 10000

  @previous_interval_keep_factor 0.5

  # We want to react quickly to failures, hence for every
  # @bump_failure_query_amount_for_tick (possibly plus one) failed
  # queries within an interval we will increase the
  # database_failure_load by @bump_load_increase_per_tick
  @bump_failure_query_amount_for_tick 5
  @bump_load_increase_per_tick 0.2

  @moduledoc """
  Helps to spread workloads coming into the database.

  The WorkloadInfo server allows you to throttle your sparql
  queries.  It allows the system to pause execution on some queries in
  order to let other queries pass through.  This is mainly meant as a
  backoff mechanism in case many queries are failing around the same
  time.  In this mechanism we want to ensure queries don't get
  executed if they hose the database.

  # General idea

  This service receives information about when queries run and when
  they succeed or fail.

  # Technical construction

  When queries pop up, this service is allowed to postpone the running of the query.

  It is given control to decide when the query service may be ran.  As
  such, this service knows when queries have started to run.  When a
  query succeeds or fails, this service is informed.  As such, the
  service has a decent clue on the load on the database.  When
  failures start coming it, it will at some point shift into a
  recovery mode.  This mode will first execute all the update queries,
  then read_for_write queries and then read queries.  This makes the
  endpoint temporarily unavailable.

  # Considerations

  It may be that a single process executes many queries in parallel.
  We're currently assuming that not to be the case.  Although this
  assumption seems harsh, it's more likely to be the case than not as
  you'd most likely (and in the current construction always) run these
  queries in separate processes which then in turn have separate PIDs.
  """

  # NOTE: the order of @query_types is the order in which we will
  # execute the queries when reaching the @non_recovery_max_running
  @query_types [:write, :read_for_write, :read]
  @type t :: %Workload{
          running_pid_map: %{read: [pid], write: [pid], read_for_write: [pid]},
          waiting_from_map: %{read: [pid], read_for_write: [pid], write: [pid]},
          running_count: integer,
          recovery_mode: boolean,
          last_interval_failure_count: integer,
          last_interval_success_count: integer,
          database_failure_load: float,
          last_finished_workload: %Workload{last_finished_workload: nil} | nil,
          start_time: DateTime.t()
        }

  @type query_types :: SparqlClient.query_types()

  @doc """
  Indicates whether or not we should run the WorkloadInfo logic.
  """
  @spec enabled?() :: boolean
  def enabled?() do
    Application.get_env(:"mu-authorization", :database_recovery_mode_enabled)
  end

  @doc """
  Reports the backend successfully sending a response.
  """
  @spec report_success(query_types) :: :ok
  def report_success(query_type) do
    if enabled?() do
      GenServer.cast(__MODULE__, {:report_success, self(), query_type})
    else
      :ok
    end
  end

  @doc """
  Reports the backend failing to send a response.
  """
  @spec report_failure(query_types) :: :ok
  def report_failure(query_type) do
    if enabled?() do
      GenServer.cast(__MODULE__, {:report_failure, self(), query_type})
    else
      :ok
    end
  end

  @spec report_timeout(query_types) :: :ok
  def report_timeout(query_types) do
    # Follows same flow as report_cancellation
    report_cancellation(query_types)
  end

  @spec report_cancellation(query_types) :: :ok
  def report_cancellation(query_type) do
    # Follows same flow as report_timeout
    if enabled?() do
      GenServer.cast(__MODULE__, {:report_cancellation, self(), query_type})
    else
      :ok
    end
  end

  @doc """
  Executes a timeout in case of read requests.
  """
  @spec timeout(query_types, integer) :: :ok
  def timeout(query_type, max_timeout \\ 60_000) do
    # TODO: allow a waiting mechanism, similar to timeout for partially
    # executed queries like DELETE INSERT
    if enabled?() do
      try do
        GenServer.call(__MODULE__, {:timeout, query_type}, max_timeout)
      catch
        :exit, {:timeout, call_info} ->
          report_cancellation(query_type)
          exit({:timeout, call_info})
      end
    else
      :ok
    end
  end

  @spec start_clocktick() :: pid
  def start_clocktick() do
    Logging.EnvLog.log(:log_database_recovery_mode_tick, "Starting WorkloadInfo clockticks")

    spawn(fn ->
      Process.sleep(@initial_clocktick_interval)
      continue_clocktick()
    end)
  end

  def continue_clocktick() do
    spawn(fn ->
      Process.sleep(@clocktick_interval)
      continue_clocktick()
    end)

    GenServer.cast(__MODULE__, :clocktick)

    Logging.EnvLog.log(
      :log_database_recovery_mode_tick,
      "Pushed WorkloadInfo clocktick on message stack"
    )
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state, 25000)
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    start_clocktick()
    {:ok, %Workload{}}
  end

  def handle_cast(:clocktick, %Workload{} = workload) do
    last_finished_workload = workload

    old_failure_factor = workload.database_failure_load * @previous_interval_keep_factor

    new_failure_factor =
      workload.last_interval_failure_count /
        (workload.last_interval_success_count + workload.last_interval_failure_count)

    new_failure_load =
      if workload.last_interval_failure_count == 0 do
        # lower hard when no failures are detected
        # TODO: with the new watermark numbers, the max should be 1 so .... this has no value
        min(1, 0.2 * old_failure_factor)
      else
        @previous_interval_keep_factor * old_failure_factor +
          (1 - @previous_interval_keep_factor) * new_failure_factor
      end

    new_recovery_mode =
      if workload.recovery_mode do
        if workload.last_interval_failure_count <= @failure_load_min_failures &&
             Enum.empty?(workload.waiting_from_map[:write]) &&
             Enum.empty?(workload.waiting_from_map[:read_for_write]) &&
             new_failure_load < @failure_load_recovery_score do
          false
        else
          true
        end
      else
        # Note: you can reach recovery_mode faster if many failing
        # requests arrive within one clocktick_interval
        new_failure_load > @failure_load_recovery_score &&
          workload.last_interval_failure_count >= @failure_load_min_failures
      end

    new_workload = %{
      workload
      | database_failure_load: new_failure_load,
        recovery_mode: new_recovery_mode,
        last_interval_success_count: 0,
        last_interval_failure_count: 0,
        last_finished_workload: %{last_finished_workload | last_finished_workload: nil},
        start_time: DateTime.utc_now()
    }

    {:noreply, new_workload}
  end

  @impl true
  def handle_cast(
        {:report_success, pid, query_type},
        workload
      ) do
    workload =
      workload
      |> remove_running_pid(query_type, pid)
      |> update_in([:last_interval_success_count], &(&1 + 1))
      |> trigger_new_queries

    {:noreply, workload}
  end

  @impl true
  def handle_cast(
        {:report_failure, pid, query_type},
        workload
      ) do
    workload =
      workload
      |> remove_running_pid(query_type, pid)
      |> update_in([:last_interval_failure_count], &(&1 + 1))
      |> mid_clocktick_failure_load_update
      |> trigger_new_queries

    {:noreply, workload}
  end

  @impl true
  def handle_cast(
        {:report_cancellation, pid, query_type},
        workload
      ) do
    workload =
      workload
      |> remove_running_pid(query_type, pid)
      |> trigger_new_queries

    {:noreply, workload}
  end

  @impl true
  def handle_call(:get_state, _from, workload) do
    {:reply, workload, workload}
  end

  @impl true
  def handle_call(
        {:timeout, query_type},
        from,
        workload
      ) do
    {pid, _} = from
    Process.monitor(pid)

    workload =
      workload
      |> queue_from(query_type, from)
      |> trigger_new_queries

    {:noreply, workload}
  end

  @impl true
  def handle_info(
        {:DOWN, _reference, _process, pid, _error},
        %Workload{
          running_pid_map: pid_map,
          waiting_from_map: from_map
        } = workload
      ) do
    pid_match = &(&1 == pid)
    from_match = fn {pid, _} -> pid_match.(pid) end

    running_read_map = Enum.reject(pid_map[:read], pid_match)
    running_write_map = Enum.reject(pid_map[:write], pid_match)
    running_read_for_write_map = Enum.reject(pid_map[:read_for_write], pid_match)

    waiting_read_map = Enum.reject(from_map[:read], from_match)
    waiting_write_map = Enum.reject(from_map[:write], from_match)
    waiting_read_for_write_map = Enum.reject(from_map[:read_for_write], from_match)

    workload
    # update running counts and maps
    |> put_in(
      [:running_count],
      Enum.count(running_read_map) + Enum.count(running_write_map) +
        Enum.count(running_read_for_write_map)
    )
    |> put_in([:running_pid_map, :read], running_read_map)
    |> put_in([:running_pid_map, :write], running_write_map)
    |> put_in([:running_pid_map, :read_for_write], running_read_for_write_map)
    # update waiting counts and maps
    |> put_in([:waiting_pid_map, :read], waiting_read_map)
    |> put_in([:waiting_pid_map, :write], waiting_write_map)
    |> put_in([:waiting_pid_map, :read_for_write], waiting_read_for_write_map)
    |> trigger_new_queries
    |> wrap_in_noreply
  end

  @spec remove_running_pid(t, query_types, pid) :: t
  defp remove_running_pid(workload, query_type, pid) do
    # Lowers the running count and removes the pid (once) from the
    # respective list.
    workload
    |> update_in([:running_count], &(&1 - 1))
    |> update_in([:running_pid_map, query_type], &List.delete(&1, pid))
  end

  @spec launch_client(t, query_types, GenServer.from()) :: t
  defp launch_client(workload, query_type, from) do
    # Launch a new client
    GenServer.reply(from, :ok)

    {from_pid, _} = from

    # Update workload
    workload
    |> update_in([:running_count], &(&1 + 1))
    |> update_in([:waiting_from_map, query_type], &List.delete(&1, from))
    |> update_in([:running_pid_map, query_type], fn x -> [from_pid | x] end)

    # We already have a monitor from the :timeout and don't need to set
    # up a new one
  end

  @spec queue_from(t, query_types, GenServer.from()) :: t
  defp queue_from(workload, query_type, from) do
    workload
    |> update_in([:waiting_from_map, query_type], &(&1 ++ [from]))
  end

  defp wrap_in_noreply(thing) do
    {:noreply, thing}
  end

  ### Semi-public interface, to be used for debugging.

  @spec trigger_new_queries(t) :: t
  def trigger_new_queries(
        %Workload{recovery_mode: false, running_count: running_count} = workload
      )
      when running_count < @non_recovery_max_running do
    queries_to_launch = @non_recovery_max_running - running_count

    # We take the first queries_to_launch options and launch them
    new_workload =
      @query_types
      |> Enum.map(fn query_type ->
        workload.waiting_from_map[query_type]
        |> Enum.map(fn from -> {query_type, from} end)
      end)
      |> Enum.concat()
      |> Enum.take(queries_to_launch)
      |> Enum.reduce(workload, fn {query_type, from}, workload ->
        launch_client(workload, query_type, from)
      end)

    new_workload
  end

  def trigger_new_queries(%Workload{recovery_mode: true} = workload) do
    # Find the recovery mode running type we are in
    running_type = recovery_running_type(workload)
    max_of_type = @recovery_max[running_type]

    # We only count the queries of the current type, rather than all
    # queries, for reaching our max running count as during error
    # recovery there could be some long-running queries in the other
    # types that hose the repair otherwise.
    running_count = Enum.count(workload.running_pid_map[running_type])
    queries_to_launch = max_of_type - running_count

    if queries_to_launch > 0 do
      workload.waiting_from_map[running_type]
      |> Enum.take(queries_to_launch)
      |> Enum.reduce(workload, fn from, workload ->
        launch_client(workload, running_type, from)
      end)
    else
      workload
    end
  end

  def trigger_new_queries(%Workload{} = workload) do
    # Do nothing, we just have to wait
    workload
  end

  @doc """
  Gets the running type in case of recovery mode, or nil if we are not
  in recovery mode.

  This is the type of queries we should be running.  This is thus the
  most important type of query which we are either running or which we
  could be running.
  """
  @spec recovery_running_type(t) :: query_types | nil
  def recovery_running_type(%Workload{recovery_mode: false}),
    do: nil

  def recovery_running_type(workload) do
    cond do
      !Enum.empty?(workload.running_pid_map.write) -> :write
      !Enum.empty?(workload.waiting_from_map.write) -> :write
      !Enum.empty?(workload.running_pid_map.read_for_write) -> :read_for_write
      !Enum.empty?(workload.waiting_from_map.read_for_write) -> :read_for_write
      !Enum.empty?(workload.running_pid_map.read) -> :read
      !Enum.empty?(workload.waiting_from_map.read) -> :read
      true -> :read
    end
  end

  _ = """
  Handles updating of load and recovery state during a clocktick.
  """

  @spec mid_clocktick_failure_load_update(t) :: t
  defp mid_clocktick_failure_load_update(workload) do
    workload
    |> increase_failure_load_during_clocktick()
    |> update_recovery_mode_during_clocktick()
  end

  _ = """
  Increases the database load in case we have failed too many times in
  this interval.
  """

  @spec increase_failure_load_during_clocktick(t) :: t
  defp increase_failure_load_during_clocktick(workload) do
    cond do
      is_zero(@bump_load_increase_per_tick) ->
        workload

      is_zero(@bump_failure_query_amount_for_tick) ->
        workload

      true ->
        interval_failure_count = workload.last_interval_failure_count

        failure_tick_rem =
          Integer.mod(interval_failure_count + 1, @bump_failure_query_amount_for_tick)

        is_failure_tick = failure_tick_rem == 0

        if is_failure_tick do
          update_in(workload.database_failure_load, &(&1 + @bump_load_increase_per_tick))
        else
          workload
        end
    end
  end

  @spec update_recovery_mode_during_clocktick(t) :: t
  defp update_recovery_mode_during_clocktick(workload) do
    update_in(
      workload.recovery_mode,
      &(&1 ||
          (workload.last_interval_failure_count > @failure_load_min_failures &&
             workload.database_failure_load > @failure_load_recovery_score))
    )
  end

  @spec is_zero(number) :: boolean
  defp is_zero(0), do: true
  defp is_zero(_), do: false
end
