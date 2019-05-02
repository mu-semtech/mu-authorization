alias GraphReasoner.{TypeReasoner, ModelInfo, QueryInfo}

defmodule TypeReasoner do
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
    IO.inspect(query_info, label: "query_info for fixpoint")

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

        # TODO cope with types being derived from predicates.  note that
        # combining expliict types with derived types is a bit strange.
        # The derived types should be considered sets of types which
        # limit the amount of possible types, whereas the explicit types
        # enforce items to be of a certain type.  Hence the derived
        # types could be limited by explicit types, but explicit types
        # should not be expanded by derived types.

        explicit_type_definitions =
          related_paths
          |> Enum.filter(fn path ->
            Map.has_key?(path, :predicate) && Map.has_key?(path, :object)
          end)
          |> Enum.filter(fn %{predicate: predicate} ->
            Updates.QueryAnalyzer.Iri.is_a?(predicate)
          end)
          |> Enum.map(fn %{object: {:iri, type}} -> type end)

        # IO.inspect(explicit_type_definitions, label: "explicit types")

        if start_types == explicit_type_definitions do
          {changed_ids, query_info}
        else
          new_query_info =
            QueryInfo.set_term_info_by_id(query_info, term_id, :types, explicit_type_definitions)

          {[term_id | changed_ids], new_query_info}
        end
      end
    )
  end

  @spec dependent_term_info_ids([number], QueryInfo.t()) ::
          [number]
  defp dependent_term_info_ids(_changed_term_info_ids, _query_info) do
    # TODO derive terms which could be impacted by a change in the supplied term info
    []
  end
end
