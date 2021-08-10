defmodule Delta.Cache do
  use GenServer

  @coalesce_time 2 * 1000

  def inform(delta, mu_call_id_trail) do
      GenServer.call( __MODULE__, {:inform, delta, mu_call_id_trail})
  end


  def flush(mu_call_id_trail) do
    GenServer.cast( __MODULE__, {:flush, mu_call_id_trail})
  end


  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end


  @impl true
  def init(_) do
    {:ok, %{}}
  end


  defp touch_timeout(state, mu_call_id_trail) do
    ref = Process.send_after(self(), {:timeout, mu_call_id_trail}, @coalesce_time)
    new_state = Map.update(state, mu_call_id_trail, %{buffer: [], ref: ref}, fn x ->
      Process.cancel_timer(x.ref)
      # Keep buffer intact
      %{x | ref: ref}
    end)

    new_state
  end


  defp do_flush(state, mu_call_id_trail) do
    # Remove possible timeout things
    {cache, new_state} = Map.pop(state, mu_call_id_trail)

    Process.cancel_timer(cache.ref)

    json_model = %{
      "changeSets" => cache.buffer
    }

    json_model
    |> IO.inspect(label: "hallooooo")
    |> Poison.encode!()
    |> Delta.Messenger.inform_clients(mu_call_id_trail: mu_call_id_trail)

    new_state
  end


  # TODO: this message might be incorrect, cause it was already in queue, after a touch message
  @impl true
  def handle_info({:timeout, trail}, state) do
    new_state = do_flush(state, trail)

    {:noreply, new_state}
  end


  @impl true
  def handle_cast({:flush, trail}, state) do
    {:noreply, do_flush(state, trail)}
  end


  @impl true
  def handle_call({:inform, delta, trail}, _from, state) do
    new_state = touch_timeout(state, trail)
    |> update_in([trail, :buffer], &(&1 ++ delta))

    {:reply, :ok, new_state}
  end
end
