defmodule TypeReasoner do
  alias Updates.QueryAnalyzer.Iri
  alias GraphReasoner.{TypeReasoner, ModelInfo, QueryInfo}

  @moduledoc """
  The TypeReasoner derives types for known entities and pushes the
  types around.

  TODO: The type reasoner should cope with types of related variables.
  """

  @doc """
  Derives the types based on the info available about the terms in
  term_ids and term_info, augmented with available information about
  the model found through model_info.
  """
  @spec derive_types(QueryInfo.t(), ModelInfo.t()) :: QueryInfo.t()
  def derive_types(query_info, model_info) do
    term_info_ids =
      query_info
      |> QueryInfo.terms_map()
      |> Map.get(:term_ids)
      |> Map.values()
      |> Enum.uniq()

    derive_types_to_fixpoint(term_info_ids, query_info, model_info)
  end

  @spec derive_types_to_fixpoint([number], QueryInfo.t(), ModelInfo.t()) :: QueryInfo.t()
  defp derive_types_to_fixpoint([], query_info, _) do
    query_info
  end

  defp derive_types_to_fixpoint(term_info_ids, query_info, model_info) do
    {changed_term_info_ids, new_query_info} =
      derive_types_to_fixpoint_iteration(term_info_ids, query_info, model_info)

    new_term_info_ids = dependent_term_info_ids(changed_term_info_ids, query_info)

    derive_types_to_fixpoint(new_term_info_ids, new_query_info, model_info)
  end

  @spec derive_types_to_fixpoint_iteration([number], QueryInfo.t(), ModelInfo.t()) ::
          {[number], QueryInfo.t()}
  defp derive_types_to_fixpoint_iteration(term_info_ids, query_info, _model_info) do
    # IO.inspect(query_info, label: "query_info for fixpoint")

    # NOTE: this code mixes up the "and" type which you get by
    # explicitly defining types and the "or" type which we can derive
    # from the predicate.  This does not have strong downsides in the
    # short run as we'll almost always have one source type.

    Enum.reduce(
      term_info_ids,
      {[], query_info},
      fn term_id, {changed_ids, query_info} ->
        related_paths = QueryInfo.get_term_info_by_id(query_info, term_id, :related_paths)
        start_types = QueryInfo.get_term_info_by_id(query_info, term_id, :types)

        # IO.inspect(term_id, label: "term id")
        # IO.inspect(related_paths, label: "related paths")
        # IO.inspect(start_types, label: "start_types")

        # go over each of the related paths and derive info from them

        # TODO support definitions where anything may be a variable
        # TODO support typing in which we know (a set of) types for the object

        # specified by ?foo a :Bar.
        explicit_type_definitions =
          related_paths
          |> Enum.filter(fn path ->
            Map.has_key?(path, :predicate) && Map.has_key?(path, :object)
          end)
          |> Enum.filter(fn %{predicate: {:iri, predicate}} ->
            Iri.is_a?(predicate)
          end)
          |> Enum.map(fn %{object: {:iri, type}} -> type end)
          |> Enum.map(&Map.get(&1, :iri))
          |> Enum.map(&Iri.unwrap_iri_string/1)

        # specified because predicates don't appear in all classes
        implicit_type_definitions =
          related_paths
          |> Enum.filter(fn path ->
            Map.has_key?(path, :predicate) && Map.has_key?(path, :object)
          end)
          |> Enum.map(&Map.get(&1, :predicate))
          |> Enum.map(&elem(&1, 1))
          |> Enum.filter(fn predicate ->
            not Iri.is_a?(predicate)
          end)
          |> Enum.map(&Map.get(&1, :iri))
          |> Enum.map(&Iri.unwrap_iri_string/1)
          |> Enum.map(&ModelInfo.predicate_domain/1)
          |> type_range_intersection

        # IO.inspect(explicit_type_definitions, label: "explicit types")
        # IO.inspect(implicit_type_definitions, label: "implicit types")

        resulting_type_definitions =
          cond do
            explicit_type_definitions != [] -> explicit_type_definitions
            implicit_type_definitions != [] -> implicit_type_definitions
            true -> nil
          end

        if start_types == resulting_type_definitions do
          {changed_ids, query_info}
        else
          new_query_info =
            QueryInfo.set_term_info_by_id(query_info, term_id, :types, resulting_type_definitions)

          {[term_id | changed_ids], new_query_info}
        end
      end
    )
  end

  @spec type_range_intersection([[String.t()]]) :: [String.t()]
  defp type_range_intersection([]) do
    []
  end

  defp type_range_intersection(type_ranges) do
    type_ranges
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
  end

  @spec dependent_term_info_ids([number], QueryInfo.t()) ::
          [number]
  defp dependent_term_info_ids(_changed_term_info_ids, _query_info) do
    # TODO derive terms which could be impacted by a change in the supplied term info
    []
  end
end
