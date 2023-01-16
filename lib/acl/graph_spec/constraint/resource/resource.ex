alias Acl.GraphSpec.Constraint.Resource, as: Resource

defmodule Resource do
  alias Updates.QueryAnalyzer.Iri, as: Iri
  alias Updates.QueryAnalyzer.Types.Quad, as: Quad
  alias Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol, as: PredMatch
  alias Acl.GraphSpec.Constraint.Resource.AllPredicates, as: AllPredicates
  alias Acl.GraphSpec.Constraint.Resource.NoPredicates, as: NoPredicates

  require Logger
  require ALog

  @type t :: %Resource{
          resource_types: [String.t() | :any],
          inverse_resource_types: [String.t() | :none],
          source_graph: String.t(),
          predicates: Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol.t(),
          inverse_predicates: Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol.t()
        }

  # Types of the resource to match
  defstruct [
    {:resource_types, :any},
    {:inverse_resource_types, :none},
    {:source_graph, "http://mu.semte.ch/application"},
    {:predicates, %AllPredicates{}},
    {:inverse_predicates, %NoPredicates{}}
  ]

  defimpl Acl.GraphSpec.Constraint.Protocol do
    def matching_quads(%Resource{} = resource, quads, extra_quads \\ [], ignore_source_graph \\ false) do
      # TODO: we should have the options with authorization_groups so we
      # can collect the types of a resource on a per-user basis.
      Resource.matching_quads(resource, quads, extra_quads, %{}, ignore_source_graph)
    end
  end

  @doc """
  Yields the matching quads constructed by the supplied Resource.

  ignore_source_graph allows to ignore checking of the graph from which
  the triples should originate.  This allows the same logic to be
  applied both in the case where triples are to be redistributed, as
  well as the case where we want to detect the access rights that
  belonged to a particular distribution.
  """
  def matching_quads(resource, quads, extra_quads, options,
  ignore_source_graph) do
    # Get all resources of the right type as strings
    matching_resources = find_matching_resources(resource, quads, extra_quads, options)

    # Ensure we only have quads from the right graph
    graph_quads = if ignore_source_graph do
      quads
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

  defp resources_with_types(quads, extra_quads, options) do
    # TODO: This code should cope with resources having multiple types
    all_quads = quads ++ extra_quads

    type_defs =
      all_quads
      |> Enum.filter(fn %Quad{predicate: predicate} -> Iri.is_a?(predicate) end)
      |> ALog.di("typed quads")
      # be defensive
      |> Enum.filter(&match?(%Quad{object: %Iri{}}, &1))
      |> Enum.map(fn %Quad{subject: %Iri{iri: iri}} = quad -> {iri, quad} end)
      |> ALog.di("type defs before map")
      |> Enum.into(%{})
      |> ALog.di("type map")

    resources = all_resources(quads)

    {known_resources, unknown_resources} =
      resources
      |> Enum.reduce(
        {[], []},
        fn %Iri{iri: iri} = resource, {known_resources, unknown_resources} ->
          if Map.has_key?(type_defs, iri) do
            resource_quad = Map.get(type_defs, iri)
            new_resource_tuple = {resource, Map.get(resource_quad, :object)}
            {[new_resource_tuple | known_resources], unknown_resources}
          else
            {known_resources, [resource | unknown_resources]}
          end
        end
      )

    # we need to enrich the unknown_resources
    discovered_resources = discover_resources(unknown_resources, options)

    ALog.di(discovered_resources, "Discovered resources")

    # yield all the discovered resources
    # the format is
    # [{%Iri{} = resource, %Iri{} = type}]
    known_resources ++ discovered_resources
  end

  defp discover_resources(unknown_resources, options) do
    # TODO: cope with resources for which there is no type in code
    # that calls discover_resources

    authorization_groups = Map.get(options, :authorization_groups, [])

    resource_map =
      unknown_resources
      |> ALog.di("unknown resources to discover")
      |> Cache.Types.get_types(authorization_groups)
      |> ALog.di("cached types")

    # We now have a map with various keys, and its types
    resource_map
    |> Map.keys()
    |> Enum.flat_map(fn resource_iri ->
      resource_map
      # yields a list of iri_values
      |> Map.get(resource_iri)
      |> Enum.map(fn iri_value -> {resource_iri, Iri.from_iri_string(iri_value)} end)
    end)
  end

  defp find_matching_resources(
         %Resource{resource_types: types, inverse_resource_types: inverse_types},
         quads,
         extra_quads,
         options
       ) do
    # TODO: alter the implementation of this method by one using
    # resources_with_types

    Logger.debug("Checking if quads contain resources of types #{types}")
    ALog.di(quads, "Quads to inspect")

    # TODO: wrapping of iri should be handled correctly
    wrapped_types = types != :any && Enum.map(types, &("<" <> &1 <> ">"))
    wrapped_inverse_types = inverse_types != :none && Enum.map(inverse_types, &("<" <> &1 <> ">"))

    resources_with_types(quads, extra_quads, options)
    |> ALog.di("Resources with types")
    |> Enum.filter(fn {_, %Iri{iri: type_iri}} ->
      # IO.inspect(type_iri, label: "Type iri to match")

      # TODO: clean up this logic.  It is sound but it is also rather complex
      (types == :any || Enum.member?(wrapped_types, type_iri)) &&
        (inverse_types == :none || not Enum.member?(wrapped_inverse_types, type_iri))
    end)
    |> Enum.map(fn {%Iri{iri: iri}, _} -> iri end)
    |> ALog.di("matching resources")
  end

  defp filter_by_graph(%Resource{source_graph: graph}, quads) do
    quads
    |> Enum.filter(fn %Quad{graph: %Iri{iri: graph_uri}} -> "<" <> graph <> ">" == graph_uri end)
  end

  defp find_matching_quads(_resource, matching_resources, graph_quads) do
    graph_quads
    |> Enum.filter(fn %Quad{subject: %Iri{iri: iri}} -> Enum.member?(matching_resources, iri) end)
  end

  defp find_inverse_matching_quads(_resource, matching_resources, graph_quads) do
    graph_quads
    |> Enum.filter(fn
      %Quad{object: %Iri{iri: iri}} -> Enum.member?(matching_resources, iri)
      %Quad{} -> false
    end)
  end

  defp filter_predicates(quads, %Resource{predicates: predicates_constraint}) do
    quads
    |> Enum.filter(fn %Quad{predicate: pred} -> PredMatch.member?(predicates_constraint, pred) end)
  end

  defp filter_inverse_predicates(quads, %Resource{inverse_predicates: predicates_constraint}) do
    quads
    |> Enum.filter(fn %Quad{predicate: pred} -> PredMatch.member?(predicates_constraint, pred) end)
  end
end
