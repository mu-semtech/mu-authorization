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
    IO.puts("HERE BOYYYYY")

    if Application.get_env(:"mu-authorization", :profile) do
      {:ok, file} = File.open("prof.csv", [:write])
      IO.write(file, ~s"name,start,end\n")

      {:ok, %Profiler{running: %{}, file: file, first: true}}
    else
      {:ok, %Profiler{running: %{}, file: nil, first: true}}
    end
  end

  def start_link(_init_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start(name) do
    if Application.get_env(:"mu-authorization", :profile) do
      GenServer.call(__MODULE__, {:start, name, self()})
    else
      nil
    end
  end

  def stop(id) do
    if Application.get_env(:"mu-authorization", :profile) do
      GenServer.call(__MODULE__, {:stop, id})
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
  def handle_call(
        {:stop, id},
        _from,
        %Profiler{running: running, file: file, first: first} = state
      ) do
    time = :os.system_time(:microsecond)

    {{start_time, name, pid}, new_running} = running |> Map.pop!(id)

    event = Profiler.Event.new(name, pid, start_time, time)

    if not first do
      IO.write(file, ",")
    end

    IO.write(file, Poison.encode!(event))

    new_state = %{state | running: new_running, first: false}

    {:reply, id, new_state}
  end

  @impl true
  def terminate(_, %Profiler{file: file}) do
    File.close(file)
    :normal
  end
end
