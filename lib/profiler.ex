defmodule Profiler.Event do
  defstruct [:name, :cat, :ph, :ts, :dur, :pid, :tid]

  def new(name, pid, start, end_t) do
    %Profiler.Event{
      name: name,
      cat: "Function",
      ph: "X",
      ts: start,
      dur: end_t - start,
      pid: 0,
      tid: pid
    }
  end
end

defmodule Profiler do
  use GenServer

  defstruct [:running, :file, :first]

  defp next_id do
    System.unique_integer([:monotonic])
  end

  @impl true
  def init(_) do
    if Application.get_env(:"mu-authorization", :profile) do
      {:ok, file} = File.open("/tmp/prof.json", [:write])

      IO.write(file, "{\"otherData\": {},\"traceEvents\":[\n")

      {:ok, %Profiler{running: %{}, file: file, first: true}}
    else
      {:ok, %Profiler{running: %{}, file: nil, first: true}}
    end
  end

  def start_link(_init_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # TODO: make macro
  def start(name) do
    if Application.get_env(:"mu-authorization", :profile) do
      GenServer.call(__MODULE__, {:start, name, self()})
    else
      nil
    end
  end

  def stop(x, id) do
    stop(id)
    x
  end

  # TODO: make macro
  def stop(id) do
    if Application.get_env(:"mu-authorization", :profile) do
      GenServer.cast(__MODULE__, {:stop, id})
    else
      nil
    end
  end

  def restart() do
    if Application.get_env(:"mu-authorization", :profile) do
      GenServer.cast(__MODULE__, {:restart})
    else
      nil
    end
  end

  @impl true
  def handle_call({:start, name, pid}, _from, %Profiler{running: running} = state) do
    id = next_id()
    time = :os.system_time(:microsecond)

    new_running = running |> Map.put(id, {time, name, pid})
    new_state = %{state | running: new_running}

    {:reply, id, new_state}
  end

  @impl true
  def handle_cast(
        {:stop, id},
        %Profiler{running: running, file: file, first: first} = state
      ) do
    time = :os.system_time(:microsecond)

    {{start_time, name, pid}, new_running} = running |> Map.pop!(id)

    event = Profiler.Event.new(name, pid, start_time, time)

    if not first do
      IO.write(file, ",\n")
    end

    IO.write(file, Poison.encode!(event))

    new_state = %{state | running: new_running, first: false}

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(
        {:restart},
        %Profiler{file: file}
      ) do
    File.close(file)

    case File.read("/tmp/prof.json") do
      {:ok, contents} -> IO.puts(contents <> "]}")
      _ -> nil
    end

    {:ok, new_state} = init(nil)

    {:noreply, new_state}
  end

  @impl true
  def terminate(_, %Profiler{file: file}) do
    IO.write(file, "\n]}")
    File.close(file)
    :normal
  end
end
