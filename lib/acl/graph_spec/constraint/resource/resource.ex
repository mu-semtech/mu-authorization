alias Acl.GraphSpec.Constraint.Resource, as: Resource
alias Updates.QueryAnalyzer.Iri, as: Iri
alias Updates.QueryAnalyzer.Types.Quad, as: Quad
alias Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol, as: PredMatch
alias Acl.GraphSpec.Constraint.Resource.AllPredicates, as: AllPredicates
alias Acl.GraphSpec.Constraint.Resource.NoPredicates, as: NoPredicates

defmodule Resource do
  defstruct [ :resource_type, # Type of the resource to match
              {:source_graph, "http://mu.semte.ch/application"},
              {:predicates, %AllPredicates{} },
              {:inverse_predicates, %NoPredicates{}} ]

  defimpl Acl.GraphSpec.Constraint.Protocol do
    def matching_quads( %Resource{} = resource, quads, extra_quads\\[] ) do
      Resource.matching_quads( resource, quads, extra_quads )
    end

  end

  @doc """
  Yields the matching quads constructed by the supplied Resource.
  """
  def matching_quads( resource, quads, extra_quads ) do
    # Get all resources of the right type as strings
    matching_resources =
      find_matching_resources( resource, quads, extra_quads )

    # Ensure we only have quads from the right graph
    graph_quads = filter_by_graph( resource, quads ) |> IO.inspect

    # Limit the relations, as specified in predicates and inverse_predicates
    by_relation =
      find_matching_quads( resource, matching_resources, graph_quads )
      |> filter_predicates( resource )
      |> IO.inspect
    by_inverse_relation =
      find_inverse_matching_quads( resource, matching_resources, graph_quads )
      |> filter_inverse_predicates( resource )
      |> IO.inspect

    # Our new quads are the combination of these two, positioned in the right target_graph
    by_relation ++ by_inverse_relation
  end

  defp find_matching_resources( %Resource{ resource_type: type }, quads, extra_quads ) do
    # We need to detect other resources of which we don't know the
    # types by sending another query and caching the results.
    IO.puts "Checking if quads contain resources of type #{type}"
    IO.inspect quads

    ( quads ++ extra_quads )
    |> Enum.filter( fn
      (%Quad{ object: %Iri{ iri: iri } }) -> iri == "<" <> type <> ">"
      (%Quad{}) -> false
    end )
    |> IO.inspect
    |> Enum.filter( fn (%Quad{ predicate: %Iri{ iri: iri } } ) -> iri == "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>" end )
    |> Enum.filter( fn (quad) -> Enum.member?( quads, quad ) end ) # Only yield the results from quads
    |> IO.inspect
    |> Enum.map( fn (%Quad{ subject: %Iri{ iri: resource } }) -> resource end ) # map to the resource
    |> IO.inspect
  end

  defp filter_by_graph( %Resource{ source_graph: graph }, quads ) do
    quads
    |> Enum.filter( fn (%Quad{ graph: %Iri{ iri: graph_uri } }) -> ("<" <> graph <> ">") == graph_uri end )
  end

  defp find_matching_quads( _resource, matching_resources, graph_quads ) do
    graph_quads
    |> Enum.filter( fn (%Quad{ subject: %Iri{ iri: iri } }) -> Enum.member?( matching_resources, iri ) end )
  end

  defp find_inverse_matching_quads( _resource, matching_resources, graph_quads ) do
    graph_quads
    |> Enum.filter( fn
      (%Quad{ object: %Iri{ iri: iri } }) -> Enum.member?( matching_resources, iri )
      (%Quad{}) -> false
    end )
  end

  defp filter_predicates( quads, %Resource{ predicates: predicates_constraint } ) do
    quads
    |> Enum.filter( fn (%Quad{ predicate: pred }) -> PredMatch.member?( predicates_constraint, pred ) end )
  end

  defp filter_inverse_predicates( quads, %Resource{ inverse_predicates: predicates_constraint } ) do
    quads
    |> Enum.filter( fn (%Quad{ predicate: pred }) -> PredMatch.member?( predicates_constraint, pred ) end )
  end
end
