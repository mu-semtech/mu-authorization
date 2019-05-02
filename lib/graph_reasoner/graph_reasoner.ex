alias GraphReasoner.QueryInfo, as: QueryInfo
alias GraphReasoner.QueryMatching, as: QueryMatching
alias InterpreterTerms.WordMatch, as: Word
alias InterpreterTerms.SymbolMatch, as: Sym
alias GraphReasoner.TypeReasoner

defmodule GraphReasoner do
  require Manipulators.Basics

  @non_graph_symbols [
    :Prologue,
    :SelectClause,
    # When everything is moved to
    :DatasetClause,
    # specific grahps, the
    # DatasetClause will have no
    # impact, hence it may be
    # considered a non_graph_symbol
    :SolutionModifier,
    :ValuesClause,
    # We don't do subselects for
    :GraphGraphPattern
    # now, hence
    # GraphGraphPattern is safe.
  ]

  @accepted_symbols [
    :Sparql,
    :QueryUnit,
    :Query,
    # Query
    {:Prologue, :deep},
    :SelectQuery,
    # Can only supply data, not request it
    {:ValuesClause, :deep},
    # SelectQuery
    # Will change when we start introducing new variables
    {:SelectClause, :deep},
    # Will not impact when we discovered everything
    {:DatasetClause, :deep},
    :WhereClause,
    {:SolutionModifier, :deep},
    # WhereClause
    :GroupGraphPattern,
    # We drop subselect
    :GroupGraphPatternSub,
    # We drop GraphPatternNotTriples for now
    :TriplesBlock,
    # We may need to constrain the simplicity of TriplesBlock and TriplesSameSubjectPath
    :TriplesSameSubjectPath,
    # We will inspect what we understand of this as we develop, but drop TriplesNodePath
    {:VarOrTerm, :deep},
    # We will only accept a single statement for now
    :PropertyListPathNotEmpty,
    # PropertyListPathNotEmpty,
    # these are variables
    {:VerbSimple, :deep},
    # we will not accept complex paths, but this is simply a deep structure on which we mostly need to place cardinality constraints
    {:VerbPath, :deep},
    # We drop TriplesNode, VarOrTerm is already deeply accepted
    :ObjectList,
    :Object,
    :GraphNode,
    # VarOrTerm is already deeply accepted
    :ObjectListPath,
    :ObjectPath,
    :GraphNodePath
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
    :GraphPatternNotTriples
  ]

  @moduledoc """
  Combines the parsed SELECT query with access rights and figures out
  where GRAPH statements can be used to simplify the posed query.

  Keeps track of which elements could be converted and is able to
  report back this information.  This allows us to know which queries
  could be fully dismantled, helping us identify which ACL
  configuration helped answer the query and which didn't.
  """

  @doc """
  Processes the supplied parsed query, yielding a new query and
  whether or not it was fully understood.  Queries which could not be
  processed just return {:fail}

  The first element in the response is whether or not the query was
  fully understood.  The answer is either :partial, or :full.

  The second element in the response is the new query.  In the new
  query certain statements may have been added, removed, or altered in
  order to help the query execution.  The answers to the traversed
  query must always be equivalent to the answers of the original
  query.  The most important change is wrapping statements in elements
  to indicate the GRAPH which they will come from.
  """
  def process_query(match) do
    if is_acceptable_query(match) do
      # We don't have query processing yet so we can only supply
      # partial matches.
      processed_query =
        match
        |> mark_non_graph_clauses
        |> derive_graph_statements

      completeness =
        if fully_processed?(processed_query) do
          :full
        else
          :partial
        end

      {completeness, processed_query}
    else
      {:fail}
    end
  end

  defp derive_graph_statements(match) do
    # TODO: supply matching authorization groups Current code is
    #   incorrect and assumes no UserGroup receives a parameter.
    matching_authorization_groups =
      Enum.map(Acl.UserGroups.for_use(:read), fn g ->
        {g.name, []}
      end)

    prologue_map = Manipulators.Info.prologue_map(match)

    match
    |> augment_with_terms_map
    |> join_same_terms
    |> derive_terms_information(prologue_map)
    # |> IO.inspect( label: "Derived terms information" )
    # TODO: supply authorization groups
    |> derive_term_types(GraphReasoner.ModelInfo.Config.class_description())
    |> derive_triples_information(Acl.UserGroups.for_use(:read), prologue_map)
    # |> IO.inspect(label: "Derived triples information")
    |> wrap_graph_queries(matching_authorization_groups)
    |> extract_match_from_augmented_query
  end

  @doc """
  Verifies whether or not the query is valid.  Yields truethy iff the
  query may be processed by the GraphReasoner.  If this does not yield
  truethy, the query contain content which is not understood yet.
  """
  def is_acceptable_query(match) do
    # We need to walk over the full tree to discover this is an
    # acceptable query.
    #
    # Our reasoning goes as follows ::

    # :: Walk the tree of results
    discovery_result =
      Manipulators.Basics.map_matches(match, fn item ->
        unless match?(%Sym{symbol: _symbol}, item) do
          # :: ignore the item if it is not a SymbolMatch
          {:continue}
        else
          %Sym{symbol: symbol} = item

          cond do
            Enum.find(@accepted_symbols, &match?({^symbol, :deep}, &1)) ->
              # :: deeply accepted symbols can just be accepted
              # IO.inspect( symbol, label: "This symbol is allowed without walking children" )
              {:skip}

            Enum.find(@accepted_symbols, &match?(^symbol, &1)) ->
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
    not match?({:exit, false}, discovery_result)
  end

  defp augment_with_terms_map(match) do
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

    query_info = %QueryInfo{}

    Manipulators.Basics.map_matches_with_state(query_info, match, fn query_info, item ->
      case item do
        %Sym{symbol: :Var, string: str_with_space} ->
          # TODO: In the case of a :Var, we need to strip the spaces from the :Var element in order to get the new string.  This probably needs a fix elsewhere...

          str = String.trim(str_with_space)

          {new_query_info, new_term} =
            QueryInfo.init_term(query_info, item, %{symbol_string: str})

          {:replace_and_traverse, new_query_info, new_term}

        _ ->
          {:continue, query_info}
      end
    end)
  end

  defp join_same_terms({%QueryInfo{terms_map: state} = query_info, match}) do
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
    # shadowing variables are not merged with their shadowed
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
    term_id_for_variable_name = fn name_string ->
      Map.keys(term_info)
      |> Enum.sort()
      |> Enum.find(fn idx ->
        term_info
        |> Map.get(idx)
        |> Map.get(:symbol_string)
        |> Kernel.==(name_string)
      end)
    end

    new_term_ids =
      Enum.reduce(Map.keys(term_ids), term_ids, fn term_id, term_ids ->
        new_index =
          term_info
          |> Map.get(term_id)
          |> Map.get(:symbol_string)
          |> term_id_for_variable_name.()

        Map.put(term_ids, term_id, new_index)
      end)

    # Remove unused term_info keys
    leftover_terms =
      new_term_ids
      |> Map.values()
      |> Enum.dedup()

    leftover_term_info =
      leftover_terms
      |> Enum.reduce(%{}, fn elem, acc ->
        Map.put(acc, elem, Map.get(term_info, elem))
      end)

    new_state =
      state
      |> Map.put(:term_ids, new_term_ids)
      |> Map.put(:term_info, leftover_term_info)

    updated_query_info = QueryInfo.set_terms_map(query_info, new_state)

    {updated_query_info, match}
  end

  defp derive_terms_information({query_info, match}, prologue_map) do
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

    analyze_single_triples_block = fn symbol, query_info ->
      {subjectVarOrTerm, predicateElement, objectVarOrTerm} =
        QueryMatching.TriplesBlock.first_triple!(symbol)

      cond do
        QueryMatching.VarOrTerm.var?(subjectVarOrTerm) ->
          # When it is a variable, we can update the state of that
          # variable.  For this, we first search for the other two
          # pieces of information (the predicate and the object) so we
          # can relate each.

          varSymbol = QueryMatching.VarOrTerm.var!(subjectVarOrTerm)

          pathIri = QueryMatching.PathPrimary.iri!(predicateElement, prologue_map)

          object =
            cond do
              QueryMatching.VarOrTerm.iri?(objectVarOrTerm) ->
                # IO.inspect( objectVarOrTerm, label: "is a term" )
                iri =
                  objectVarOrTerm
                  |> QueryMatching.VarOrTerm.iri!(prologue_map)

                {:iri, iri}

              QueryMatching.VarOrTerm.var?(objectVarOrTerm) ->
                # IO.inspect( objectVarOrTerm, label: "is a var" )
                {:var, QueryMatching.VarOrTerm.var!(objectVarOrTerm)}

              QueryMatching.VarOrTerm.term?(objectVarOrTerm) ->
                # IO.inspect( objectVarOrTerm, label: "is a term" )
                {:term, QueryMatching.VarOrTerm.term!(objectVarOrTerm)}
            end

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

          QueryInfo.push_term_info(query_info, varSymbol, :related_paths, %{
            predicate: pathIri,
            object: object
          })

        # QueryMatching.VarOrTerm.iri?( subjectVarOrTerm ) ->
        #   IO.puts "Subject is an IRI, no information is derived yet"
        true ->
          IO.inspect(subjectVarOrTerm, label: "Subject of TripleBlock not supported")
      end
    end

    analyzeTriplesBlock = fn symbol, query_info ->
      # Analyzes a single TriplesBlock

      # We need to extract all the TriplesBlock elements, enrich their
      # predicates, and recombine them.

      symbol
      |> QueryMatching.GroupGraphPattern.extract_triples_blocks()
      |> Enum.reduce(query_info, analyze_single_triples_block)
    end

    {new_query_info, _} =
      Manipulators.Basics.do_state_map {query_info, match}, {map, element} do
        :TriplesBlock ->
          {:continue, analyzeTriplesBlock.(element, map)}
      end

    {new_query_info, match}
  end

  @spec derive_term_types({QueryInfo.t(), any}, ModelInfo.t()) :: {QueryInfo.t(), any}
  defp derive_term_types({query_info, match}, model_info) do
    {TypeReasoner.derive_types(query_info, model_info), match}
  end

  # Calculates the intersection of two lists
  def intersection(arr_a, arr_b) do
    MapSet.intersection(MapSet.new(arr_a), MapSet.new(arr_b))
    |> MapSet.to_list()
  end

  @spec derive_triples_information({QueryInfo.t(), any()}, Acl.UserGroups.Config.t(), any()) ::
          any()
  defp derive_triples_information({query_info, match}, authorization_groups, prologue_map) do
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

    # IO.inspect( query_info, label: "Query Info in derive_triples_information" )
    # IO.inspect( authorization_groups, label: "Authorization Groups in derive_triples_information" )

    %QueryInfo{} = query_info

    derive_triples_block_info_for_single_triple = fn query_info, element ->
      # We need to discover if the current TriplesBlock means anything
      # specific.

      # First we need to fetch the information for our processing.
      # The triple's contents and the subject variable are the most
      # important in our current case.
      {subjectVarOrTerm, predicateElement, _objectVarOrTerm} =
        QueryMatching.TriplesBlock.first_triple!(element)

      # We should accept more than only variables in the subject
      varSymbol = QueryMatching.VarOrTerm.var!(subjectVarOrTerm)

      pathIri = QueryMatching.PathPrimary.iri!(predicateElement, prologue_map)

      # objectIri =
      #   objectVarOrTerm
      #   |> QueryMatching.VarOrTerm.iri!

      subject_type_strings =
        query_info
        |> QueryInfo.get_term_info(varSymbol, :types)

      # |> IO.inspect( label: "Subject type strings" )

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
        |> Enum.reduce([], fn group_spec, matching_groups ->
          # We return the relevant information for the next
          # steps this means we are searching for the graph
          # specs with the right resource types.  If such
          # GraphSpec exists, we return a new object with only
          # the allowed GraphSpec instances.  This makes the
          # content much easier to process in followup steps.
          # IO.inspect( group_spec, label: "Group spec to process" )
          matching_graph_specs =
            group_spec.graphs
            |> Enum.reduce([], fn graph_spec, acc ->
              if !Map.has_key?(graph_spec.constraint, :resource_types) ||
                   intersection(
                     graph_spec.constraint.resource_types,
                     subject_type_strings
                   ) != [] do
                [graph_spec | acc]
              else
                acc
              end
            end)

          # If there are graphs matching, create a new
          # group_spec with only these graphs.  Push the result
          # onto the filtered groups.  If note, leave the
          # matching_groups accumulator alone.
          case matching_graph_specs do
            nil -> matching_groups
            _ -> [%{group_spec | graphs: matching_graph_specs} | matching_groups]
          end
        end)
        # TODO: we should cope with descriptions which don't have a resource constraint too
        # |> IO.inspect(label: "before constraint filter")
        |> Enum.filter(fn constraint ->
          constraint.graphs != [] &&
            Enum.all?(constraint.graphs, fn graph_spec ->
              Map.has_key?(graph_spec.constraint, :resource_types)
            end)
        end)

      # Based on the subject types, we can execute a filter for
      # the predicate of this triple.

      # TODO: Inverse predicates are currently not
      # supported.  Discover how to handle inverse predicates.

      # TODO: Much of the code for this step (the structure,
      # basically) is shared with the previous step.  Removing
      # duplication will likely make the code easier to read.
      predicate_filtered_groups =
        resource_filtered_groups
        |> Enum.reduce([], fn group_spec, matching_groups ->
          # We need to verify whether or not the predicate
          # match works for any of the graph specs.  We return
          # the graph specs for which this is the case.
          matching_graph_specs =
            group_spec.graphs
            |> Enum.filter(fn graph_spec ->
              Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol.member?(
                graph_spec.constraint.predicates,
                pathIri
              )
            end)

          # Create a new group_spec with only the matching graph specs.  Push the
          # result onto the filtered groups.  If note, leave the
          # matching_groups accumulator alone.
          [%{group_spec | graphs: matching_graph_specs} | matching_groups]
        end)

      # The result of these steps would boil down to
      # predicate_filtered_groups =
      # groups
      # |> filter_groups_by_resource_type
      # |> filter_groups_by_predicate

      # We attach this information to the predicate so it can be
      # used in a later step.

      new_predicate_element =
        predicateElement
        |> ExternalInfo.put(GraphReasoner, :matching_acl_groups, predicate_filtered_groups)

      # IO.inspect( predicateElement, label: "Predicate element to enrich" )
      # IO.inspect( predicate_filtered_groups, label: "Groups matching above predicate" )

      # We update the triples_block so the new predicate is in our
      # query.
      new_triples_block =
        QueryMatching.TriplesBlock.update_predicate(element, new_predicate_element)

      # Let's check the linked content of our new triplesblock
      {_subjectVarOrTerm, newly_fetched_predicate, _objectVarOrTerm} =
        QueryMatching.TriplesBlock.single_triple!(new_triples_block)

      newly_fetched_predicate
      |> ExternalInfo.get(GraphReasoner, :matching_acl_groups)

      # |> IO.inspect( label: "ACL groups on the new predicate" )

      # {:replace_by, query_info, new_triples_block}
      new_triples_block

      # TODO: understand other Graph clauses, like the structure
      # of the URI << does this require us to add a transform
      # and always fetch for its information??? :(

      # IO.puts "Should derive TriplesBlock information here, and attach it to the predicate."
      # IO.inspect( authorization_groups, label: "Authorization groups" )
      # { :continue, query_info }
    end

    derive_triples_block_info = fn query_info, element ->
      new_element =
        element
        |> QueryMatching.GroupGraphPattern.extract_triples_blocks()
        |> Enum.map(fn triples_block ->
          derive_triples_block_info_for_single_triple.(query_info, triples_block)
        end)
        # Recombine the triples_block elements
        |> Enum.reverse()
        |> Enum.reduce(fn parent_triples_block, child_triples_block ->
          QueryMatching.TriplesBlock.set_child(
            parent_triples_block,
            child_triples_block
          )
        end)

      # |> IO.inspect( label: "Combined triples_block" )

      {:replace_by, query_info, new_element}
    end

    Manipulators.Basics.do_state_map {query_info, match}, {query_info, element} do
      :TriplesBlock ->
        # We want to replace the triplesblock with our new
        # triplesblock.  The new TriplesBlock contains information
        # about the new element.
        #
        # The triplesblock is a fairly simple element.  Hence we
        # should be able to update its contents.
        derive_triples_block_info.(query_info, element)
    end
  end

  defp wrap_graph_queries({query_info, match}, authorization_specifications) do
    # As we know from which graphs various patterns will come from, we
    # can now wrap statements in graphs.  For now, we only support
    # simple patterns where the content comes from the same graph, we
    # may introduce new variables to split subject paths in the
    # future.

    wrap_triples_blocks_with_graphs = fn query_info, element ->
      # element is a %Sym{ symbol: :GroupGraphPattern }

      element
      # 1. Ensure this only consists of TriplesBlock instances
      |> QueryMatching.GroupGraphPattern.only_triples_blocks!()
      # 2. Extract each of the TriplesBlock instances
      |> QueryMatching.GroupGraphPattern.extract_triples_blocks()
      # |> IO.inspect( label: "Extracted triples blocks" )
      # 3. Wrap the TriplesBlock in the correct graph
      |> Enum.map(fn triple ->
        predicate = QueryMatching.TriplesBlock.predicate(triple)
        matching_acl_groups = ExternalInfo.get(predicate, GraphReasoner, :matching_acl_groups)

        predicate
        # |> IO.inspect( label: "Predicate" )
        |> ExternalInfo.get(GraphReasoner, :matching_acl_groups)

        # |> IO.inspect( label: "Matching ACL groups" )

        # Figure out the graphs to use.  This should be added to the respective protocol
        # TODO: support more than one graph
        # [ acl_group ] = matching_acl_groups

        # IO.inspect( authorization_specifications, label: "Authorization specification" )
        # IO.inspect( acl_group, label: "ACL group to match" )

        # TODO: this should be a method (or use methods) from
        # Acl.GraphSpec or corresponding protocols
        matching_graphs =
          matching_acl_groups
          |> Enum.flat_map(fn acl_group ->
            acl_group_name = Map.get(acl_group, :name)

            # get the authorization specifications
            Enum.filter(authorization_specifications, fn authorization_specification ->
              elem(authorization_specification, 0) == acl_group_name
            end)
            # convert them into graphs
            |> Enum.flat_map(fn matching_specification ->
              Enum.map(Map.get(acl_group, :graphs), fn graph_spec ->
                base_graph = Map.get(graph_spec, :graph)
                parameters = elem(matching_specification, 1)
                base_graph <> Enum.join(parameters, "/")
              end)
            end)
            # remove duplicates
            |> Enum.dedup()
          end)

        # |> IO.inspect( label: "Matching graphs" )

        # IO.inspect( matching_graphs, label: "matching graphs" )
        case matching_graphs do
          [] ->
            # TODO: check whether yielding the original block
            triple

          # is sufficient in this case.  I believe we need
          # to add support for merging subsequent
          # TriplesBlock items if multiple TripleBlock
          # items are returned after each other.
          [matching_graph] ->
            # Convert the TriplesBlock into a
            # GraphPatternNotTriples>GraphGraphPattern>GroupGraphPattern>GroupGraphPatternSub>TriplesBlock
            # This last one can be inlined as a
            # GroupGraphPattern>GroupGraphPatternSub may have many
            # GraphPatternNotTriples subexpressions.
            QueryMatching.TriplesBlock.wrap_in_graph(triple, matching_graph)

          _ ->
            # Multiple graphs may match, we need to create a UNION
            # query.
            matching_graphs
            # |> IO.inspect(label: "matching graphs")
            |> Enum.map(&QueryMatching.TriplesBlock.wrap_in_graph(triple, &1))
            # |> IO.inspect(label: "wrapped in graph")
            |> Enum.map(&QueryMatching.GraphPatternNotTriples.wrap_in_group_graph_pattern/1)
            # |> IO.inspect(label: "wrapped in group graph pattern")
            |> QueryMatching.GroupGraphPattern.make_union()
            # |> IO.inspect(label: "made union")
            |> QueryMatching.GroupGraphPattern.wrap_in_graph_pattern_not_triples()

            # |> IO.inspect(label: "Wrapped in graph pattern without triples" )
        end

        # TODO: support no matching graphs (this requires joining
        # subsequent TriplesBlock entities, as GroupGraphPatternSub
        # needs to have GraphPatternNotTriples in between the
        # TriplesBlock entities)

        # TODO: If multiple access graphs would match, this would require a UNION pattern
      end)
      # |> IO.inspect( label: "Wrapped triplesblocks" )
      # >> Will yield a new array of GraphPatternNotTriples elements
      #    which we can wire together ourselves.  4. Combine the
      #    transformed TriplesBlock list (which is now a
      #    GraphPatternNotTriples list) into the received
      #    GroupGraphPattern.
      |> (fn graph_pattern_not_triples_elements ->
            %{
              element
              | submatches: [
                  %Word{word: "{"},
                  %Sym{
                    symbol: :GroupGraphPatternSub,
                    submatches: graph_pattern_not_triples_elements
                  },
                  %Word{word: "}"}
                ]
            }
          end).()
      # |> IO.inspect( label: "New GroupGraphPatternSub" )
      # >> The list of TriplesBlock items can be combined into a
      #    :GroupGraphPatternSub in which you can just dump them all.
      # 4. Execute!
      # >> Will yield a { :replace_by, query_info, new_element }
      |> (fn updated_group_graph_pattern ->
            {:replace_by, query_info, updated_group_graph_pattern}
          end).()

      # |> IO.inspect( label: "Replacement request" )
    end

    Manipulators.Basics.do_state_map {query_info, match}, {query_info, element} do
      :GroupGraphPattern ->
        # We assume a GroupGraphPatternSub with multiple
        # TriplesBlock.  This can then be replaced by
        # GroupGraphPattern|>GroupGraphPatternSub>GraphPatternNotTriples|>GraphGraphPattern|>GroupGraphPattern|>GroupGraphPatternSub
        #
        # The EBNF does not make working with this construction
        # easy.  Hence we first extract all TriplesBlock instances
        # from the GroupGraphPatternSub.  Then we convert each of
        # them into either a TriplesBlock (if we didn't understand
        # it), or to the construction mentioned above.
        wrap_triples_blocks_with_graphs.(query_info, element)
    end
  end

  defp extract_match_from_augmented_query({_query_info, match}) do
    # Consumption of the wrapped graph will likely need access to the
    # transformed query.  This function provides easy access to that
    # match.

    match
  end

  defp fully_processed?(match) do
    case Manipulators.Basics.map_matches(match, fn item ->
           if may_need_graph_clause?(item) do
             {:exit, false}
           else
             {:continue}
           end
         end) do
      {:exit, value} -> value
      _ -> true
    end
  end

  defp mark_non_graph_clauses(match) do
    Manipulators.Basics.map_matches(match, fn item ->
      case item do
        %Sym{symbol: symbol} when symbol in @non_graph_symbols ->
          new_item = ExternalInfo.put(item, GraphReasoner, :non_graph_clause, true)
          {:replace_and_traverse, new_item}

        %Sym{symbol: _symbol} ->
          {:continue}

        _ ->
          # non-symbols can be marked as safe for now
          {:replace_and_traverse, ExternalInfo.put(item, GraphReasoner, :non_graph_clause, true)}
      end
    end)
  end

  defp may_need_graph_clause?(match) do
    # We only know this can't be a graph clause if we have explicitly
    # determined it to be so.
    if ExternalInfo.has_var?(match, GraphReasoner, :non_graph_clause) do
      # If we marked the item, we know how it should behave
      not ExternalInfo.get(match, GraphReasoner, :non_graph_clause)
    else
      case match do
        %Sym{symbol: symbol, submatches: children}
        when symbol in @symbols_fully_dispatched_to_children ->
          # If it's dependent on its children, all children must be safe
          Enum.any?(children, &may_need_graph_clause?/1)

        %Sym{symbol: _symbol} ->
          # If it's a non-marked symbol
          true

        _ ->
          false
      end
    end
  end
end
