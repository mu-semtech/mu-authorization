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

  defp all_resources( quads ) do
    # Yields all resources in the supplied set of quads.  These are
    # the resources which may be of a relevant type.
    quads
    |> Enum.reduce( [], fn (%Quad{ subject: sub, object: obj }, prev_resources) ->
      resources =
        [sub, obj]
        |> Enum.filter( &match?( %Iri{}, &1 ) )
      resources ++ prev_resources
    end )
    |> Enum.uniq_by( fn (%Iri{ iri: iri }) -> iri end )
  end

  defp resources_with_types( quads, extra_quads ) do
    # TODO: This code should cope with resources having multiple types
    all_quads = quads ++ extra_quads

    type_defs =
      all_quads
      |> Enum.filter( fn (%Quad{ predicate: predicate }) -> Iri.is_a?( predicate ) end )
      |> IO.inspect( label: "typed quads" )
      |> Enum.filter( &match?(%Quad{ object: %Iri{} },&1) ) # be defensive
      |> Enum.map( fn(%Quad{ subject: %Iri{ iri: iri } } = quad) -> { iri, quad } end )
      |> IO.inspect( label: "type defs before map" )
      |> Enum.into( %{} )
      |> IO.inspect( label: "type map" )

    resources = all_resources( quads )

    { known_resources, unknown_resources } =
      resources
      |> Enum.reduce( {[],[]},
        fn (%Iri{ iri: iri } = resource, {known_resources,unknown_resources}) ->
          if Map.has_key?( type_defs, iri ) do
            resource_quad = Map.get( type_defs, iri )
            new_resource_tuple = { resource, Map.get( resource_quad, :object ) }
            { [ new_resource_tuple | known_resources ], unknown_resources }
          else
            { known_resources, [ resource | unknown_resources ] }
          end
        end )

    # we need to enrich the unknown_resources
    discovered_resources = discover_resources( unknown_resources )

    IO.inspect discovered_resources, label: "Discovered resources"

    # yield all the discovered resources
    # the format is
    # [{%Iri{} = resource, %Iri{} = type}]
    known_resources ++ discovered_resources
  end

  defp discover_resources( unknown_resources ) do
    unknown_resources
    |> IO.inspect( label: "unknown resources to discover" )
    |> Enum.flat_map( fn (%Iri{ iri: resource_iri_value } = resource_iri) ->
      # TODO: this should be based on a query that was parsed first
      # TODO: pass the right graphs to this query.  for now, it is
      # incorrectly assumed that triplestore will solve this problem
      # for us.
      # TODO: cope with resources for which there is no type in code
      # that calls discover_resources

      "SELECT DISTINCT ?type WHERE { <MY_RESOURCE> a ?type }"
      |> Parser.parse_query_full(  )
      |> Manipulators.SparqlQuery.replace_iri( "<MY_RESOURCE>", resource_iri_value )
      |> Regen.result
      |> IO.inspect( label: "query to find type for " <> resource_iri_value )
      |> SparqlClient.query
      |> SparqlClient.extract_results
      |> IO.inspect( label: "results for " <> resource_iri_value )
      |> Enum.map( fn (result) ->
        result
        |> Map.get( "type" )
        |> Map.get( "value" )
        |> (fn (value) ->
          # TODO: wrapping of iri should be handled correctly
          { resource_iri, Iri.from_iri_string( "<" <> value <> ">" ) }
        end ).()
      end )
    end )
  end

  defp find_matching_resources( %Resource{ resource_type: type }, quads, extra_quads ) do
    # TODO: alter the implementation of this method by one using
    # resources_with_types

    IO.puts "Checking if quads contain resources of type #{type}"
    IO.inspect quads

    # TODO: wrapping of iri should be handled correctly
    wrapped_type  = "<" <> type <> ">"

    resources_with_types( quads, extra_quads )
    |> IO.inspect( label: "Resources with types" )
    |> Enum.filter( fn ({_, %Iri{ iri: type_iri }}) -> type_iri == wrapped_type end )
    |> Enum.map( fn({ %Iri{ iri: iri }, _ } ) -> iri end )
    |> IO.inspect( label: "matching resources" )
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
