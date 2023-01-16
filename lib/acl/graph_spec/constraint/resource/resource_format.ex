alias Acl.GraphSpec.Constraint.ResourceFormat, as: ResourceFormat

defmodule ResourceFormat do
  alias Updates.QueryAnalyzer.Iri, as: Iri
  alias Updates.QueryAnalyzer.Types.Quad, as: Quad
  alias Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol, as: PredMatch
  alias Acl.GraphSpec.Constraint.Resource.AllPredicates, as: AllPredicates
  alias Acl.GraphSpec.Constraint.Resource.NoPredicates, as: NoPredicates

  require Logger
  require ALog

  # TODO: DRY up with respect to Acl.GraphSpec.Constraint.Resource

  # prefix of the resource
  defstruct [
    :resource_prefix,
    {:source_graph, "http://mu.semte.ch/application"},
    {:predicates, %AllPredicates{}},
    {:inverse_predicates, %NoPredicates{}}
  ]

  defimpl Acl.GraphSpec.Constraint.Protocol do
    def matching_quads(%ResourceFormat{} = resource, quads, extra_quads \\ [], ignore_source_graph \\ false) do
      # TODO: we should have the options with authorization_groups so we
      # can collect the types of a resource on a per-user basis.
      IO.puts("Matching quads for ResourceFormat")
      ResourceFormat.matching_quads(resource, quads, extra_quads, %{}, ignore_source_graph)
    end
  end

  @doc """
  Yields the matching quads constructed by the supplied Resource.
  """
  def matching_quads(resource, quads, extra_quads, options, ignore_source_graph) do
    # Get all resources of the right type as strings
    matching_resources =
      find_matching_resources(resource, quads, extra_quads, options)
      |> ALog.di("matching resources")

    # Ensure we only have quads from the right graph
    graph_quads = if ignore_source_graph do
      matching_resources
    else
      filter_by_graph(resource, quads) |> ALog.di("Graph filtered quads")
    end

    # Limit the relations, as specified in predicates and inverse_predicates
    by_relation =
      find_matching_quads(resource, matching_resources, graph_quads)
      |> filter_predicates(resource)
      |> ALog.di("filtered predicates")

    by_inverse_relation =
      find_inverse_matching_quads(resource, matching_resources, graph_quads)
      |> filter_inverse_predicates(resource)
      |> ALog.di("filtered inverse predicates")

    # Our new quads are the combination of these two, positioned in the right target_graph
    by_relation ++ by_inverse_relation
  end

  defp all_resources(quads) do
    # Yields all resources in the supplied set of quads.  These are
    # the resources which may be of a relevant type.
    quads
    |> Enum.reduce([], fn %Quad{subject: sub, object: obj}, prev_resources ->
      resources =
        [sub, obj]
        |> Enum.filter(&match?(%Iri{}, &1))

      resources ++ prev_resources
    end)
    |> Enum.uniq_by(fn %Iri{iri: iri} -> iri end)
  end

  defp find_matching_resources(
         %ResourceFormat{resource_prefix: prefix},
         quads,
         _extra_quads,
         _options
       ) do
    # TODO: alter the implementation of this method by one using
    # resources_with_types

    Logger.debug("Checking if quads contain resources with prefix #{prefix}")
    ALog.di(quads, "Quads to inspect")

    prefix_byte_size = byte_size(prefix)
    first_char_byte_size = byte_size("<")

    all_resources(quads)
    |> Enum.filter(fn %Iri{iri: iri} ->
      iri_byte_size = byte_size(iri)
      # we would do iri_bytesize >= prefix_bytesize, but we need to
      # cut off the first < anyways.
      if iri_byte_size >= prefix_byte_size + first_char_byte_size do
        <<_::binary-size(first_char_byte_size), first_chars::binary-size(prefix_byte_size),
          _::binary>> = iri

        first_chars == prefix
      end
    end)
    |> ALog.di("matching resources")
  end

  defp filter_by_graph(%ResourceFormat{source_graph: graph}, quads) do
    quads
    |> Enum.filter(fn %Quad{graph: %Iri{iri: graph_uri}} -> "<" <> graph <> ">" == graph_uri end)
  end

  defp find_matching_quads(_resource, matching_resources, graph_quads) do
    ALog.di(matching_resources, "Resources to match")
    ALog.di(graph_quads, "Quads to check")

    matching_resources = Enum.map(matching_resources, fn %Iri{iri: iri} -> iri end)

    graph_quads
    |> Enum.filter(fn %Quad{subject: %Iri{iri: iri}} -> Enum.member?(matching_resources, iri) end)
  end

  defp find_inverse_matching_quads(_resource, matching_resources, graph_quads) do
    ALog.di(matching_resources, "Inverse resources to match")
    ALog.di(graph_quads, "Inverse quads to check")

    matching_resources = Enum.map(matching_resources, fn %Iri{iri: iri} -> iri end)

    graph_quads
    |> Enum.filter(fn
      %Quad{object: %Iri{iri: iri}} -> Enum.member?(matching_resources, iri)
      %Quad{} -> false
    end)
  end

  defp filter_predicates(quads, %ResourceFormat{predicates: predicates_constraint}) do
    quads
    |> Enum.filter(fn %Quad{predicate: pred} -> PredMatch.member?(predicates_constraint, pred) end)
  end

  defp filter_inverse_predicates(quads, %ResourceFormat{inverse_predicates: predicates_constraint}) do
    quads
    |> Enum.filter(fn %Quad{predicate: pred} -> PredMatch.member?(predicates_constraint, pred) end)
  end
end
