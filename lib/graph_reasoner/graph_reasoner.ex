defmodule GraphReasoner do
  @non_graph_symbols [:Prologue,
                      :SelectClause,
                      :DatasetClause, # When everything is moved to
                                      # specific grahps, the
                                      # DatasetClause will have no
                                      # impact, hence it may be
                                      # considered a non_graph_symbol
                      :SolutionModifier,
                      :ValuesClause,
                      :GraphGraphPattern # We don't do subselects for
                                         # now, hence
                                         # GraphGraphPattern is safe.
                     ]

  @accepted_symbols [:Sparql,
                     :QueryUnit,
                     :Query,
                     # Query
                     {:Prologue,:deep},
                     :SelectQuery,
                     {:ValuesClause,:deep}, # Can only supply data, not request it
                     # SelectQuery
                     {:SelectClause,:deep}, # Will change when we start introducing new variables
                     {:DatasetClause,:deep}, # Will not impact when we discovered everything
                     :WhereClause,
                     {:SolutionModifier,:deep},
                     # WhereClause
                     :GroupGraphPattern,
                     :GroupGraphPatternSub, # We drop subselect
                     :TriplesBlock, # We drop GraphPatternNotTriples for now
                     :TriplesSameSubjectPath, # We may need to constrain the simplicity of TriplesBlock and TriplesSameSubjectPath
                     {:VarOrTerm,:deep}, # We will inspect what we understand of this as we develop, but drop TriplesNodePath
                     :PropertyListPathNotEmpty, # We will only accept a single statement for now
                     # PropertyListPathNotEmpty,
                     {:VerbSimple,:deep}, # these are variables
                     {:VerbPath,:deep}, # we will not accept complex paths, but this is simply a deep structure on which we mostly need to place cardinality constraints
                     :ObjectList,:Object,:GraphNode, # We drop TriplesNode, VarOrTerm is already deeply accepted
                     :ObjectListPath,:ObjectPath,:GraphNodePath, # VarOrTerm is already deeply accepted
                    ]

  @symbols_fully_dispatched_to_children [
    :Sparql,
    :QueryUnit,
    :Query,
    :SelectQuery,
    :WhereClause,
    :GroupGraphPattern,
    :GroupGraphPatternSub,
    :TriplesBlock,
    :GraphPatternNotTriples ]

  @moduledoc """
  Combines the parsed SELECT query with access rights and figures out
  where GRAPH statements can be used to simplify the posed query.

  Keeps track of which elements could be converted and is able to
  report back this information.  This allows us to know which queries
  could be fully dismantled, helping us identify which ACL
  configuration helped answer the query and which didn't.
  """


  @doc """
  Processes the supplied parced query, yielding a new query and
  whether or not it was fully understood.  Queries which could not be
  processed just return {:fail}

  The first element in the response is whether or not the query was
  fully understood.  The answer is either :partial, or :full.

  The secend element in the response is the new query.  In the new
  query certain statements may have been added, removed, or altered in
  order to help the query execution.  The answers to the traversed
  query must always be equivalent to the answers of the original
  query.  The most important change is wrapping statements in elements
  to indicate the GRAPH which they will come from.
  """
  def process_query( match ) do
    if is_acceptable_query( match ) do
      # We don't have query processing yet so we can only supply
      # partial matches.
      processed_query =
        match
        |> mark_non_graph_clauses
        |> derive_graph_statements

      completeness = if fully_processed?( processed_query ) do :full else :partial end

      { completeness, processed_query }
    else
      { :fail }
    end
  end

  defp derive_graph_statements( match ) do
    match
    |> augment_with_terms_map
    |> join_same_terms
    |> derive_terms_information
    |> derive_triples_information( Acl.UserGroups.for_use( :read ) ) # TODO: supply authorization groups
    |> wrap_graph_queries( nil )
    |> extract_match_from_augmented_query
  end

  @doc """
  Verifies whether or not the query is valid.  Yields truethy iff the
  query may be processed by the GraphReasoner.  If this does not yield
  truethy, the query contain content which is not understood yet.
  """
  def is_acceptable_query( match ) do
    # We need to walk over the full tree to discover this is an
    # acceptable query.
    #
    # Our reasoning goes as follows ::

    discovery_result =
      # :: Walk the tree of results
      Manipulators.Basics.map_matches( match, fn (item) ->
        unless match?( %InterpreterTerms.SymbolMatch{ symbol: _symbol }, item ) do
          # :: ignore the item if it is not a SymbolMatch
          { :continue }
        else
          %InterpreterTerms.SymbolMatch{ symbol: symbol } = item
          cond do
            Enum.find( @accepted_symbols, &match?( {^symbol,:deep}, &1 ) ) ->
              # :: deeply accepted symbols can just be accepted
              # IO.inspect( symbol, label: "This symbol is allowed without walking children" )
              {:skip}
            Enum.find( @accepted_symbols, &match?( ^symbol, &1) ) ->
              # :: accepted symbols are allowed, but their children have to be checked
              # IO.inspect( symbol, label: "This symbol is allowed if children are allowed" )
              {:continue}
            true ->
              # :: no match was found for this symbol, the query cannot be accepted
              # IO.inspect( symbol, label: "This symbol is not allowed" )
              {:exit, false}
          end
        end
      end)

    # map_matches doesn't just exit with the exit result, it informs
    # us that an exit happened.  We need to convert it to the expected
    # result.
    not match?( {:exit, false}, discovery_result )
  end

  defp augment_with_terms_map( match ) do
    # This method consumes a match and generates a terms_map from the
    # statements.  The terms_map is a knowledge-base connecting terms
    # to the information derived from them (eg:
    # <http://example.com/cars/1> is of type
    # <http://example.com/Car>).
    #
    # Construction of the terms map limits itself to identifying each
    # term in the query, providing a new identifier for it, and
    # creating an entry in the terms map for it.

    # As we can't store objects by reference and update them, we need
    # to build our own pointer system to achieve state which can be
    # manipulated.  There are many alternatives, we choose to identify
    # each variable by a number.  Because we assume that we'll
    # discover some variables overlap (eg: the variable ?s is used in
    # multiple places and its meaning isn't shadowed), we need a way
    # to group information later on.  As such, we have created a
    # 'term_ids' map, which maps from the identifier of a variable, to
    # its corresponding information in the 'terms_info' hash.  When we
    # discover that we can group variables together, we can do so by
    # manipulating these two hashes, rather than by finding and
    # manipulating the complex query object.
    state = %{ term_ids: %{}, term_info: %{}, term_ids_index: 0, term_info_index: 0 }

    { state, query } = Manipulators.Basics.map_matches_with_state( state, match, fn ( state, item ) ->
      %{ term_ids: term_ids,
         term_info: term_info,
         term_ids_index: term_ids_index,
         term_info_index: term_info_index
       } = state
      case item do
        %InterpreterTerms.SymbolMatch{ symbol: :Var, string: str_with_space } ->
          # TODO: In the case of a :Var, we need to strip the spaces from the :Var element in order to get the new string.  This probably needs a fix elsewhere...

          str = String.trim( str_with_space )

          new_term_ids_index = term_ids_index + 1
          new_term_info_index = term_info_index + 1

          new_term_ids = Map.put( term_ids, new_term_ids_index, new_term_info_index )
          new_term_info = Map.put( term_info, new_term_info_index, %{symbol_string: str} )
          new_item = ExternalInfo.put( item, GraphReasoner, :term_id, new_term_ids_index )

          new_state =
            state
            |> Map.put( :term_ids, new_term_ids )
            |> Map.put( :term_info, new_term_info )
            |> Map.put( :term_ids_index, new_term_ids_index )
            |> Map.put( :term_info_index, new_term_info_index )

          { :replace_and_traverse, new_state, new_item }
        _ ->
          { :continue, state }
      end
    end )

    { state, query }
  end

  defp join_same_terms( { state, match } ) do
    # When interpreting the query we may start understanding more
    # about its variables.  We parse the query, discover information
    # about how the variables are related, and join up related
    # variables.

    # It is fairly easy to join terms together with our current
    # assumptions.  Because we don't support subqueries, variables
    # cannot be shadowed.  In the current implementation we can walk
    # over the existing variables, without further analyzing the
    # query.

    # TODO: when subqueries are allowed: analyze the query to ensure
    # shadewing variables are not merged with their shadowed
    # name-fellow.

    # Another assumption we can make in the current construction, is
    # that there is virtually no information available on the items.
    # Because this step is currently not called iteratively, we know
    # there is only a name available.  Therefore, we don't need to
    # group the statements together.

    # TODO: perform logical joining of terms when terms are joined
    # iteratively.

    term_ids = Map.get(state, :term_ids)
    term_info = Map.get(state, :term_info)

    # helper function to get the identifier for a given name string
    term_id_for_variable_name = fn (name_string) ->
      Map.keys( term_info )
      |> Enum.sort
      |> Enum.find( fn(idx) ->
        term_info
        |> Map.get( idx )
        |> Map.get( :symbol_string )
        |> Kernel.==( name_string )
      end )
    end

    new_term_ids =
      Enum.reduce( Map.keys( term_ids ), term_ids, fn ( term_id, term_ids ) ->
        new_index =
          term_info
          |> Map.get( term_id )
          |> Map.get( :symbol_string )
          |> term_id_for_variable_name.()

        Map.put( term_ids, term_id, new_index )
      end )

    new_state = Map.put( state, :term_ids, new_term_ids )

    # TODO: we could remove the term_info of unused keys to ease
    # debugging.

    { new_state, match }
  end

  defp derive_terms_information( { terms_map, match } ) do
    # Each of the terms in the query may express information about the
    # variables.  For instance, when we see ?s a foaf:Agent, we know
    # that ?s is of type foaf:Agent.  We can use this information in
    # other places.  For each of these statements, we can augment the
    # knowledge expressed in the terms_map.  This information is
    # essential to later derive which information is likely stored in
    # which place.

    # We currently assume only simple triple statements.  Furthermore,
    # we ignore the prologue and assume all URIs are written in their
    # long form (for now).  Because of this, we can limit ourselves to
    # the most minimal interpretation of the query.

    analyzeTriplesBlock = fn (terms_map, symbol) ->
      # Analyzes a single TriplesBlock

      { subjectVarOrTerm, predicateElement, objectVarOrTerm } =
        GraphReasoner.QueryMatching.TriplesBlock.single_triple!( symbol )

      cond do
        GraphReasoner.QueryMatching.VarOrTerm.var?( subjectVarOrTerm ) ->
          # When it is a variable, we can update the state of that
          # variable.  For this, we first search for the other two
          # pieces of information (the predicate and the object) so we
          # can relate each.

          varSymbol = GraphReasoner.QueryMatching.VarOrTerm.var!( subjectVarOrTerm )

          pathIri = GraphReasoner.QueryMatching.PathPrimary.iri!( predicateElement )

          objectIri =
            objectVarOrTerm
            |> GraphReasoner.QueryMatching.VarOrTerm.iri!
            |> Updates.QueryAnalyzer.Iri.from_symbol

          # TODO: don't crash when predicates or objects are not URIs.
          # The previous section assumes both will be an Iri, but
          # there are absolutely no guarantees that will be the case.
          # In both of these cases, we want to refer to the identifier
          # available in the external_info of the symbol so we can
          # keep updating its contents.

          # Now that we know the variable, the path's iri and the
          # object's iri, we can add that information to the content
          # we've discovered.

          # TODO: Discover types based on where the content may reside
          # (eg: if the predicate foaf:name can only originate from a
          # foaf:Agent, we should use this information).

          term_id = ExternalInfo.get( varSymbol, GraphReasoner, :term_id )
          renamed_term_id = terms_map.term_ids[term_id]

          new_terms_map =
            update_in(
              terms_map[:term_info][renamed_term_id][:related_paths],
              fn (related_paths) ->
                [ %{ predicate: pathIri, object: objectIri } | (related_paths || []) ]
              end )

          new_terms_map

        # GraphReasoner.QueryMatching.VarOrTerm.iri?( subjectVarOrTerm ) ->
        #   IO.puts "Subject is an IRI, no information is derived yet"
        true ->
          IO.inspect subjectVarOrTerm, label: "Subject of TripleBlock not supported"
      end
    end


    { new_terms_map, _ } =
      Manipulators.Basics.map_matches_with_state( terms_map, match, fn (terms_map, element) ->
        case element do
          %InterpreterTerms.SymbolMatch{
            symbol: :TriplesBlock
          } ->
            new_terms_map = analyzeTriplesBlock.( terms_map, element )
            { :continue, new_terms_map }
          _ -> { :continue, terms_map }
        end
      end )

    { new_terms_map, match }
  end

  # Calculates the intersection of two lists
  def intersection( arr_a, arr_b ) do
    Enum.reduce( arr_a, [], fn( a_elt, result ) ->
      if( Enum.find( arr_b, fn (b_elt) -> b_elt == a_elt end ) ) do
        [ a_elt | result ]
      else
        result
      end
    end )
  end

  defp derive_triples_information( { terms_map, match }, authorization_groups ) do
    # Each of the triples which needs to be fetched may be fetched
    # from various graphs.  Based on the information in the terms_map,
    # the access groups of the current user, and the specific triple
    # to be discovered, we can detect where this information should
    # come from.  We attach this information to the predicate as that
    # will keep working when we decide to support subject paths.

    # In order for this approach to work, we have to assume a closed
    # world assumption with respect to the Acl.UserGroups
    # configuration.  This implicit assumption is also made for
    # determining the graphs where content should come from.

    # Based on the information known in the variables, and the
    # information of the UserGroups, we derive *each* graph from which
    # the information could be read.

    # We make the same assumptions as above, where we state that we
    # only support trivial `s p o` matches, and nothing with real
    # paths or variables.

    deriveTriplesBlockInformation = fn (terms_map, element) ->
      # We need to discover if the current TriplesBlock means anything
      # specific.

      # First we need to fetch the information for our processing.
      # The triple's contents and the subject variable are the most
      # important in our current case.
      { subjectVarOrTerm, predicateElement, objectVarOrTerm } =
        GraphReasoner.QueryMatching.TriplesBlock.single_triple!( element )

      # TODO: how will we push the predicate back into the
      # TriplesBlock?  Should that be a helper supplied from there?

      cond do
        GraphReasoner.QueryMatching.VarOrTerm.var?( subjectVarOrTerm ) ->
          varSymbol = GraphReasoner.QueryMatching.VarOrTerm.var!( subjectVarOrTerm )

          pathIri = GraphReasoner.QueryMatching.PathPrimary.iri!( predicateElement )

          objectIri =
            objectVarOrTerm
            |> GraphReasoner.QueryMatching.VarOrTerm.iri!
            |> Updates.QueryAnalyzer.Iri.from_symbol

          term_id = ExternalInfo.get( varSymbol, GraphReasoner, :term_id )
          renamed_term_id = terms_map.term_ids[term_id]
          subject_info = terms_map[:term_info][renamed_term_id][:related_paths]
          {subject_types, related_predicates} =
            subject_info
            |> Enum.reduce( {[],[]}, fn (%{predicate: predicate, object: object} = pred_obj, {types,preds}) ->
              # TODO: Accept different information than only subject and predicate
              if Updates.QueryAnalyzer.Iri.is_a?( predicate ) do
                # Add the object to the types
                {[object|types],preds}
              else
                # Add the pred_obj to the related predicates
                {types,[pred_obj|preds]}
              end
            end )

          subject_type_strings =
            subject_types
            |> Enum.map( fn (%Updates.QueryAnalyzer.Iri{iri: str} ) ->
                 Updates.QueryAnalyzer.Iri.unwrap_iri_string( str )
               end )

          # Next up, we need to discover which graphs match the
          # information we've gathered so far.  Based on the
          # information attached to the subject, we can figure out in
          # which graphs this piece of information could be stored.

          # For this, we need to compare the information we have about
          # the subject, and compare it with the information we have
          # on the graph clauses.  For each clause that may match, we
          # have to remember the ACL specification and the resulting
          # graphs.

          # Note: in order to achieve this, we need to validate *all*
          # groups, and identify which groups can *not* match.  By
          # ensuring we remove all places from which the content could
          # never come, we are sure to have understood all rules, and
          # not accidentally dropped something off.  For some specific
          # rules, we may choose to 'drop' them unless certain
          # information is known.

          # We do a first filtering based on the subject types
          resource_filtered_groups =
            authorization_groups
            |> Enum.reduce( [], fn ({group_spec, parameters}, matching_groups) ->
                 # We return the relevant information for the next
                 # steps this means we are searching for the graph
                 # specs with the right resource types.  If such
                 # GraphSpec exists, we return a new object with only
                 # the allowed GraphSpec instances.  This makes the
                 # content much easier to process in followup steps.
                 matching_graph_specs =
                   group_spec.graphs
                   |> Enum.reduce( [], fn (graph_spec, acc) ->
                        if ! Map.has_key?( graph_spec.constraint, :resource_types )
                           || intersection( graph_spec.constraint.resource_types,
                                            subject_type_strings ) != []
                         do
                           [ graph_spec | acc ]
                         else
                           acc
                        end
                      end )

                 # If there are graphs matching, create a new
                 # group_spec with only these graphs.  Push the result
                 # onto the filtered groups.  If note, leave the
                 # matching_groups accumulator alone.
                 case matching_graph_specs do
                   nil -> matching_groups
                   _ -> [ %{ group_spec | graphs: matching_graph_specs } | matching_groups ]
                 end
               end )
            # TODO: we should cope with descriptions which don't have a resource constraint too
            |> Enum.filter( fn (constraint) ->
              constraint.graphs != [] &&
              Enum.all?( constraint.graphs, fn (graph_spec) ->
                Map.has_key?( graph_spec.constraint, :resource_types )
              end )
            end )

          # Based on the subject types, we can execute a filter for
          # the predicate of this triple.

          # TODO: Inverse predicates are currently not
          # supported.  Discover how to handle inverse predicates.

          # TODO: Much of the code for this step (the structure,
          # basically) is shared with the previous step.  Removing
          # duplication will likely make the code easier to read.
          predicate_filtered_groups =
            resource_filtered_groups
            |> Enum.reduce( [], fn (group_spec, matching_groups) ->
                 # We need to verify whether or not the predicate
                 # match works for any of the graph specs.  We return
                 # the graph specs for which this is the case.
                 matching_graph_specs =
                   group_spec.graphs
                   |> Enum.reduce( [], fn (graph_spec, acc) ->
                        if Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol.member?(
                              graph_spec.constraint.predicates,
                              pathIri )
                        do
                          [ graph_spec | acc ]
                        else
                          acc
                        end
                      end )
                 # If there are graphs matching, create a new
                 # group_spec with only these graphs.  Push the result
                 # onto the filtered groups.  If note, leave the
                 # matching_groups accumulator alone.
                 case matching_graph_specs do
                   nil -> matching_groups
                   _ -> [ %{ group_spec | graphs: matching_graph_specs } | matching_groups ]
                 end
               end )

          # The result of these steps would boil down to
          # predicate_filtered_groups =
          # groups
          # |> filter_groups_by_resource_type
          # |> filter_groups_by_predicate

          # We attach this information to the predicate so it can be
          # used in a later step.

          new_predicate_element =
            predicateElement
            |> ExternalInfo.put( GraphReasoner, :matching_acl_groups, predicate_filtered_groups )

          # We update the triples_block so the new predicate is in our
          # query.
          new_triples_block = GraphReasoner.QueryMatching.TriplesBlock.update_predicate( element, new_predicate_element )

          {:replace_by, terms_map, new_triples_block}

          # TODO: understand other Graph clauses, like the structure
          # of the URI << does this require us to add a transform
          # and always fetch for its information??? :(

        # GraphReasoner.QueryMatching.VarOrTerm.iri?( subjectVarOrTerm ) ->
        #   IO.puts "Subject is an IRI, no information is derived yet"
        true ->
          IO.inspect subjectVarOrTerm, label: "Subject of TripleBlock not supported"
          {:continue, terms_map}
      end

      # IO.puts "Should derive TriplesBlock information here, and attach it to the predicate."
      # IO.inspect( authorization_groups, label: "Authorization groups" )
      # { :continue, terms_map }
    end

    { new_terms_map, new_match } =
      Manipulators.Basics.map_matches_with_state( terms_map, match, fn (terms_map, element) ->
        case element do
          %InterpreterTerms.SymbolMatch{
            symbol: :TriplesBlock
          } ->
            # We want to replace the triplesblock with our new
            # triplesblock.  The new TriplesBlock contains information
            # about the new element.
            #
            # The triplesblock is a fairly simple element.  Hence we
            # should be able to update its contents.
            deriveTriplesBlockInformation.( terms_map, element )
          _ -> { :continue, terms_map }
        end
      end )

    { new_terms_map, new_match }
  end

  defp wrap_graph_queries( { terms_map, match }, authorization_specifications ) do
    # As we know from which graphs various patterns will come from, we
    # can now wrap statements in graphs.  For now, we only support
    # simple patterns where the content comes from the same graph, we
    # may introduce new variables to split subject paths in the
    # future.

    wrap_triples_blocks_with_graphs = fn (terms_map, element) ->
      # element is a %InterpreterTerms.SymbolMatch{ symbol: :GroupGraphPattern }

      element
      # 1. Ensure this only consists of TriplesBlock instances
      |> GraphReasoner.QueryMatching.GroupGraphPattern.only_triples_blocks!
      # 2. Extract each of the TriplesBlock instances
      |> GraphReasoner.QueryMatching.GroupGraphPattern.extract_triples_blocks
      # |> IO.inspect( label: "Extracted triples blocks" )
      # 3. Wrap the TriplesBlock in the correct graph
      |> Enum.map( fn (triple) ->
        predicate = GraphReasoner.QueryMatching.TriplesBlock.predicate( triple )
        matching_acl_groups = ExternalInfo.get( predicate, GraphReasoner, :matching_acl_groups )

        predicate
        |> ExternalInfo.get( GraphReasoner, :matching_acl_groups )
        # |> IO.inspect( label: "Matching ACL groups" )

        # Figure out the graphs to use.  This should be added to the respective protocol
        # TODO: support more than one graph
        [ acl_group ] = matching_acl_groups

        # IO.inspect( authorization_specifications, label: "Authorization specification" )
        # IO.inspect( acl_group, label: "ACL group to match" )

        # TODO: this should be a method (or use methods) from
        # Acl.GraphSpec or corresponding protocols
        matching_graphs =
          matching_acl_groups
          |> Enum.flat_map( fn (acl_group) ->
            acl_group_name = Map.get( acl_group, :name )

            # get the authorization specifications
            Enum.filter( authorization_specifications, fn (authorization_specification) ->
              elem( authorization_specification, 0 ) == acl_group_name
            end )
            # convert them into graphs
            |> Enum.flat_map( fn (matching_specification) ->
              Enum.map( Map.get( acl_group, :graphs ), fn (graph_spec) ->
                base_graph = Map.get(graph_spec, :graph)
                parameters = elem( matching_specification, 1 )
                base_graph <> Enum.join( parameters, "/" )
              end )
            end )
            # remove duplicates
            |> Enum.dedup
          end )
          # |> IO.inspect( label: "Matching graphs" )

        # TODO: support more than one matching graph
        [matching_graph] = matching_graphs

        # Convert the TriplesBlock into a GraphPatternNotTriples>GraphGraphPattern>GroupGraphPattern>GroupGraphPatternSub>TriplesBlock
        # This last one can be inlined as a GroupGraphPattern>GroupGraphPatternSub may have many GraphPatternNotTriples subexpressions.

        # TODO: If multiple access graphs would match, this would require a UNION pattern
        GraphReasoner.QueryMatching.TriplesBlock.wrap_in_graph( triple, matching_graph )
      end )
      # |> IO.inspect( label: "Wrapped triplesblocks" )
      # >> Will yield a new array of GraphPatternNotTriples elements
      #    which we can wire together ourselves.  4. Combine the
      #    transformed TriplesBlock list (which is now a
      #    GraphPatternNotTriples list) into the received
      #    GroupGraphPattern.
      |> (fn (graph_pattern_not_triples_elements) ->
            %{ element |
               submatches: [
                 %InterpreterTerms.WordMatch{ word: "{" },
                 %InterpreterTerms.SymbolMatch{
                   symbol: :GroupGraphPatternSub,
                   submatches: graph_pattern_not_triples_elements
                 },
                 %InterpreterTerms.WordMatch{ word: "}" }
               ] }
          end).()
      # |> IO.inspect( label: "New GroupGraphPatternSub" )
      # >> The list of TriplesBlock items can be combined into a
      #    :GroupGraphPatternSub in which you can just dump them all.
      # 4. Execute!
      # >> Will yield a { :replace_by, terms_map, new_element }
      |> (fn (updated_group_graph_pattern) ->
            { :replace_by, terms_map, updated_group_graph_pattern }
          end ).()
      # |> IO.inspect( label: "Replacement request" )
    end

    { new_terms_map, new_match } =
      Manipulators.Basics.map_matches_with_state( terms_map, match, fn (terms_map, element) ->
        case element do
          %InterpreterTerms.SymbolMatch{
            symbol: :GroupGraphPattern
          } ->
            # We assume a GroupGraphPatternSub with multiple
            # TriplesBlock.  This can then be replaced by
            # GroupGraphPattern|>GroupGraphPatternSub>GraphPatternNotTriples|>GraphGraphPattern|>GroupGraphPattern|>GroupGraphPatternSub
            #
            # The EBNF does not make working with this construction
            # easy.  Hence we first extract all TriplesBlock instances
            # from the GroupGraphPatternSub.  Then we convert each of
            # them into either a TriplesBlock (if we didn't understand
            # it), or to the construction mentioned above.
            wrap_triples_blocks_with_graphs.(terms_map, element)
          _ -> { :continue, terms_map }
        end
      end )
  end

  defp extract_match_from_augmented_query( { _terms_map, match } ) do
    # Consumption of the wrapped graph will likely need access to the
    # transformed query.  This function provides easy access to that
    # match.

    match
  end

  defp fully_processed?( match ) do
    case Manipulators.Basics.map_matches( match, fn (item) ->
          if may_need_graph_clause?( item ) do
            { :exit, false }
          else
            { :continue }
          end
        end )
      do
      { :exit, value } -> value
      _ -> true
    end
  end

  defp mark_non_graph_clauses( match ) do
    Manipulators.Basics.map_matches( match, fn (item) ->
      case item do
        %InterpreterTerms.SymbolMatch{ symbol: symbol } when symbol in @non_graph_symbols ->
          new_item = ExternalInfo.put item, GraphReasoner, :non_graph_clause, true
          { :replace_and_traverse, new_item }
        %InterpreterTerms.SymbolMatch{ symbol: symbol } ->
          { :continue }
        _ ->
          # non-symbols can be marked as safe for now
          { :replace_and_traverse, ExternalInfo.put( item, GraphReasoner, :non_graph_clause, true ) }
      end
    end )
  end

  defp may_need_graph_clause?( match )do
    # We only know this can't be a graph clause if we have explicitly
    # determined it to be so.
    if ExternalInfo.has_var?( match, GraphReasoner, :non_graph_clause ) do
      # If we marked the item, we know how it should behave
      not ExternalInfo.get( match, GraphReasoner, :non_graph_clause )
    else
      case match do
        %InterpreterTerms.SymbolMatch{ symbol: symbol, submatches: children } when symbol in @symbols_fully_dispatched_to_children ->
          # If it's dependent on its children, all children must be safe
          Enum.any? children, &may_need_graph_clause?/1
        %InterpreterTerms.SymbolMatch{ symbol: symbol } ->
          # If it's a non-marked symbol
          true
        _ ->
          false
      end
    end
  end

end
