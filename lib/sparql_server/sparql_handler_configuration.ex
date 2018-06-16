defmodule SPARQLServer.SPARQLHandlerConfiguration do
  @moduledoc """
  This file is intended to be overridden by different implementations of this service
  """
  def get_config() do
    [
      %{
        name: Ingest,
        add_query: fn(arr, q) ->
          IO.puts "in p1 adding..."
          q |> inspect |> IO.puts
          IO.puts DateTime.to_string(DateTime.utc_now())
          rarr = Enum.reverse(arr)
          Enum.reverse([q|rarr])
        end,
        pick_query: fn([f|r]) ->
          IO.puts "in p1 picking"
          f |> inspect |> IO.puts
          IO.puts DateTime.to_string(DateTime.utc_now())
          {:continue, r, f}
        end,
        process_query: fn(q) ->
          IO.puts "in p1 processing"
          q |> inspect |> IO.puts
          IO.puts DateTime.to_string(DateTime.utc_now())
          :timer.sleep(2000)
          {:next, :none, q <> " LIMIT 5"}
        end,
      },
      %{
        name: PerformQuery,
        add_query: fn(arr, q) ->
          IO.puts "in p2 adding..."
          q |> inspect |> IO.puts
          IO.puts DateTime.to_string(DateTime.utc_now())
          [q|arr]
        end,
        pick_query: fn([f|r]) ->
          IO.puts "in p2 picking"
          f |> inspect |> IO.puts
          IO.puts DateTime.to_string(DateTime.utc_now())
          {:wait, r, f}
        end,
        process_query: fn(q) ->
          IO.puts "in p2 processing"
          q |> inspect |> IO.puts
          IO.puts DateTime.to_string(DateTime.utc_now())
          resp = Poison.encode!(SPARQLClient.query(q))
          # IO.puts(resp)
          {:stop, resp, q}
        end,
      }
    ]
  end
end
