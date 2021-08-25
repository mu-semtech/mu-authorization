defmodule CacheType do
  alias Updates.QueryAnalyzer
  alias Updates.QueryAnalyzer.P, as: QueryAnalyzerProtocol
  alias Updates.QueryAnalyzer.Types.Quad, as: Quad

  require Logger
  require ALog

  defmodule ConstructAndAsk do
    @enforce_keys [:triple_counts, :triples_in_store]
    defstruct [:triple_counts, :triples_in_store]
  end

  defmodule OnlyAsk do
    defstruct []
  end

  defmodule MultipleConstructs do
    @enforce_keys [:non_overlapping_quads]
    defstruct [:non_overlapping_quads]
  end

  defmodule Select do
    @enforce_keys [:quads_in_store]
    defstruct [:quads_in_store]
  end

  defp quad_in_store_with_ask?(quad) do
    (QueryAnalyzer.construct_ask_query(quad)
     |> SparqlClient.execute_parsed(query_type: :read))["boolean"]
  end

  ## Create tuple from literal {type, value}
  defp get_result_tuple(x) do
    out = QueryAnalyzerProtocol.to_sparql_result_value(x)
    {out.type, out.value}
  end

  defp tuple_from_bindings(%{"o" => object, "s" => subject, "p" => predicate, "g" => graph}) do
    {
      {graph["type"], graph["value"]},
      {subject["type"], subject["value"]},
      {predicate["type"], predicate["value"]},
      {object["type"], object["value"]}
    }
  end

  defp tuple_from_bindings(%{"o" => object, "s" => subject, "p" => predicate}) do
    {
      {subject["type"], subject["value"]},
      {predicate["type"], predicate["value"]},
      {object["type"], object["value"]}
    }
  end

  defp query_to_results(query) do
    query
    |> SparqlClient.execute_parsed(query_type: :read)
    |> Map.get("results")
    |> Map.get("bindings")
    |> Enum.map(&tuple_from_bindings/1)
    |> MapSet.new()
  end

  # From current quads, analyse what quads are already present
  defp triples_in_store_with_construct(quads) do
    quads
    |> QueryAnalyzer.construct_asks_query()
    |> query_to_results()
  end

  def quads_in_store_with_select(quads) do
    quads
    |> QueryAnalyzer.construct_select_distinct_matching_quads()
    |> query_to_results()
  end

  # From current quads, calculate frequency of _triple_
  # Equal quads have no influence, but same triples from different graphs
  # cannot be queried with the same CONSTRUCT query
  # (because CONSTRUCT only returns triples)
  defp triple_counts_with_graph_differences(quads) do
    quads
    |> Enum.uniq()
    |> Enum.map(fn %Quad{
                     subject: subject,
                     predicate: predicate,
                     object: object,
                     graph: _graph
                   } ->
      {get_result_tuple(subject), get_result_tuple(predicate), get_result_tuple(object)}
    end)
    |> Enum.frequencies()
  end

  defp quad_equal_without_graph(
         %Quad{
           subject: s1,
           predicate: p1,
           object: o1
         },
         %Quad{
           subject: s2,
           predicate: p2,
           object: o2
         }
       ) do
    s1 == s2 and p1 == p2 and o1 == o2
  end

  defp split_into_nonoverlapping(cum, []) do
    cum
  end

  defp split_into_nonoverlapping(cum, xs) do
    # if el can merge into acc, return {[], acc ++ el}
    # else {[el], acc}
    el_can_merge = fn el, acc ->
      not Enum.any?(el, fn x -> Enum.any?(acc, &quad_equal_without_graph(x, &1)) end)
    end

    {xs, cum} =
      Enum.flat_map_reduce(xs, cum, fn el, acc ->
        # TODO check syntax!
        (el_can_merge.(el, acc) && {[], acc ++ el}) || {[el], acc}
      end)

    [cum | split_into_nonoverlapping([], xs)]
  end

  defp merge_quads_in_non_overlapping_quads(quads) do
    # Filter per graph
    # Merge seperate graphs
    # return quads
    per_graph =
      Enum.group_by(quads, fn x -> x.graph end)
      |> Map.values()

    split_into_nonoverlapping([], per_graph)
  end

  defp quad_list_to_constructed_graphs(quads) do
    graphs =
      Enum.map(quads, fn x -> get_result_tuple(x.graph) end)
      |> MapSet.new()

    triples_in_store = triples_in_store_with_construct(quads)
    {graphs, triples_in_store}
  end

  # Test if a quad is inn the store
  # If the calculated frequency is one, the existence of the triple in the CONSTRUCT query
  # uniquely represents the existence of the quad in the triplestore
  # If the calculated frequency is more, the triple might exist in more graphs
  # so the CONSTRUCT query does not uniquely represent the quad in the triplestore
  # so an ASK query is executed (this shouldn't happen too often)
  def create_cache_type(:construct, quads) do
    triple_counts = triple_counts_with_graph_differences(quads)
    triples_in_store = triples_in_store_with_construct(quads)

    %ConstructAndAsk{triple_counts: triple_counts, triples_in_store: triples_in_store}
  end

  def create_cache_type(:select, quads) do
    quads_in_store = quads_in_store_with_select(quads)

    %Select{quads_in_store: quads_in_store}
  end

  def create_cache_type(:multiple_constructs, quads) do
    non_overlapping_quads =
      merge_quads_in_non_overlapping_quads(quads)
      |> Enum.map(&quad_list_to_constructed_graphs/1)

    %MultipleConstructs{non_overlapping_quads: non_overlapping_quads}
  end

  def create_cache_type(:only_asks, _quads) do
    %OnlyAsk{}
  end

  def quad_in_store?(%MultipleConstructs{non_overlapping_quads: non_overlapping_quads}, %Quad{
        subject: subject,
        predicate: predicate,
        object: object,
        graph: graph
      }) do
    IO.puts("quad in store with MultipleConstructs")
    g = get_result_tuple(graph)
    value = {get_result_tuple(subject), get_result_tuple(predicate), get_result_tuple(object)}

    {_, quads_in_this_store} = Enum.find(non_overlapping_quads, fn {gs, _} -> g in gs end)

    value in quads_in_this_store
  end

  def quad_in_store?(%Select{quads_in_store: quads_in_store}, %Quad{
        subject: subject,
        predicate: predicate,
        object: object,
        graph: graph
      }) do
    IO.puts("quad in store with Select")

    value =
      {get_result_tuple(graph), get_result_tuple(subject), get_result_tuple(predicate),
       get_result_tuple(object)}

    value in quads_in_store
  end

  def quad_in_store?(%OnlyAsk{}, quad) do
    IO.puts("quad in store with OnlyAsk")
    quad_in_store_with_ask?(quad)
  end

  def quad_in_store?(
        %ConstructAndAsk{
          triple_counts: triple_counts,
          triples_in_store: triples_in_store
        },
        %Quad{
          subject: subject,
          predicate: predicate,
          object: object,
          graph: _graph
        } = quad
      ) do
    IO.puts("quad in store with ConstructAndAsk")

    value = {get_result_tuple(subject), get_result_tuple(predicate), get_result_tuple(object)}

    if Map.get(triple_counts, value, 0) > 1 do
      quad_in_store_with_ask?(quad)
    else
      value in triples_in_store
    end
  end
end
