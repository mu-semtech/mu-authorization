defmodule SPARQLServer.SPARQLHandlerConfiguration do
  @moduledoc """
  This file is intended to be overridden by different implementations of this service
  """
  def get_config() do
    [
      %{
        name: PROCESS1,
        add_query: fn(arr, q) ->
          IO.puts "in p1 adding..."
          IO.puts q
          IO.puts DateTime.to_string(DateTime.utc_now())
          rarr = Enum.reverse(arr)
          Enum.reverse([q|rarr])
        end,
        pick_query: fn([f|r]) ->
          IO.puts "in p1 picking"
          IO.puts f
          IO.puts DateTime.to_string(DateTime.utc_now())
          {:continue, r, f}
        end,
        process_query: fn(q, n) ->
          IO.puts "in p1 processing"
          IO.puts q
          IO.puts DateTime.to_string(DateTime.utc_now())
          :timer.sleep(2000)
          {:next, n, q}
        end,
      },
      %{
        name: PROCESS2,
        add_query: fn(arr, q) ->
        IO.puts "in p2 adding..."
        IO.puts q
        IO.puts DateTime.to_string(DateTime.utc_now())
        [q|arr]
        end,
        pick_query: fn([f|r]) ->
          IO.puts "in p2 picking"
          IO.puts f
          IO.puts DateTime.to_string(DateTime.utc_now())
          {:wait, r, f}
        end,
        process_query: fn(q, n) ->
          IO.puts "in p2 processing"
          IO.puts q
          IO.puts DateTime.to_string(DateTime.utc_now())
          q
          |> SPARQLClient.query
          |> Poison.encode!
          |> IO.puts
          {:next, n, q}
        end,
      }
    ]
  end
end
