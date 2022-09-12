defmodule Manipulator.Transform do
  def quad_pattern_to_group_graph_pattern(quad_pattern) do
    quad_pattern
    |> Regen.result(:QuadPattern)
    |> String.trim()
    |> Parser.parse_query_full(:GroupGraphPattern)
  end

  def quad_data_to_group_graph_pattern(quad_data) do
    quad_data
    |> Regen.result(:QuadData)
    |> String.trim()
    |> Parser.parse_query_full(:GroupGraphPattern)
  end
end
