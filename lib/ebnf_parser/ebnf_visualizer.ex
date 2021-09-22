defmodule EbnfParser.Visualizer do
  @moduledoc """
  Parses the EBNF and is able to render the necessary node information
  to visualize using visjs.
  """

  def print_nodes_for_sparql_visjs do
    {nodes, edges} = nodes_for_sparql_visjs_in_json_string()
    IO.puts("nodes")
    IO.puts(nodes)
    IO.puts("edges")
    IO.puts(edges)
  end

  def nodes_for_sparql_visjs_in_json_string do
    {nodes, edges} = EbnfParser.Visualizer.nodes_for_sparql_visjs_in_poison()
    {Poison.encode!(nodes), Poison.encode!(edges)}
  end

  @doc """
  Yields a Poison structure which can be used to render a visjs graph
  of the SPARQL EBNF.
  """
  def nodes_for_sparql_visjs_in_poison do
    sparql_statements = EbnfParser.Sparql.sparql_syntax_as_ordered_array()
    amount_of_sparql_statements = Enum.count(sparql_statements)

    sparql_statements
    |> Enum.reduce({0, []}, fn elt, {idx, previous_nodes_and_edges} ->
      completion_percentage = (0.1 + idx) / amount_of_sparql_statements
      new_nodes_and_edges = nodes_for_ebnf_form(elt, completion_percentage)
      {idx + 1, [new_nodes_and_edges | previous_nodes_and_edges]}
    end)
    |> elem(1)
    |> Enum.reduce({[], []}, fn {new_nodes, new_edges}, {old_nodes, old_edges} ->
      {new_nodes ++ old_nodes, new_edges ++ old_edges}
    end)
  end

  @doc """
  Yields an array of nodes and an array of edges as Poison objects
  which can be used to render visjs supported nodes and edges.
  """
  def nodes_for_ebnf_form(form, percentage_completed) do
    {ebnf_string, {name, {terminal, real_form}}} = form
    sub_symbols = symbols_for_parsed_form(real_form)
    nodes_for_ebnf_form(name, ebnf_string, sub_symbols, terminal, percentage_completed)
  end

  # def nodes_for_ebnf_form( _, _, _, true, _ ) do
  #   {[],[]}
  # end
  def nodes_for_ebnf_form(
        source_symbol,
        ebnf_string,
        target_symbols,
        terminal,
        completion_percentage
      ) do
    node_color = node_color_for_percentage(completion_percentage)

    nodes = [
      %{
        "id" => to_string(source_symbol),
        "label" => to_string(source_symbol),
        "terminal" => terminal,
        "color" => node_color,
        "title" => ebnf_string
      }
    ]

    # terminal
    edges =
      if false do
        []
      else
        Enum.map(
          target_symbols,
          fn target -> %{"from" => to_string(source_symbol), "to" => to_string(target)} end
        )
      end

    {nodes, edges}
  end

  defp node_color_for_percentage(completion_percentage) do
    hue = round(360 * completion_percentage)
    saturation = round((1 - completion_percentage) * 100)
    lightness = round(50 + (95 - 50) * completion_percentage)
    alpha = 1 - completion_percentage * 0.5
    "hsla(#{hue},#{saturation}%,#{lightness}%,#{alpha})"
  end

  @doc """
  Yields a list of symbols which appeared in the parsed form.
  """
  def symbols_for_parsed_form(form) do
    form
    |> recursive_symbols_for_parsed_form([])
    |> Enum.uniq()
  end

  defp recursive_symbols_for_parsed_form(form, solutions) when is_list(form) do
    Enum.reduce(form, solutions, fn item, acc ->
      case item do
        {:symbol, sym} -> [sym | acc]
        {_, sub} -> recursive_symbols_for_parsed_form(sub, acc)
      end
    end)
  end

  defp recursive_symbols_for_parsed_form(_, solutions) do
    solutions
  end
end
