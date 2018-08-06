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
        #|> derive_graph_statements

      completeness = if fully_processed?( processed_query ) do :full else :partial end

      { completeness, processed_query }
    else
      { :fail }
    end
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
        unless match?( %InterpreterTerms.SymbolMatch{ symbol: symbol }, item ) do
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

  defp fully_processed?( match ) do
    case Manipulators.Basics.map_matches( match, fn (item) ->
          if may_need_graph_clause?( match ) do
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
          IO.inspect symbol, label: "Not a graph symbol"
          new_item = ExternalInfo.put item, GraphReasoner, :non_graph_clause, true
          { :replace_and_traverse, new_item }
        %InterpreterTerms.SymbolMatch{ symbol: symbol } ->
          IO.inspect symbol, label: "Skipping symbol"
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
          IO.inspect symbol, label: "May needs graph clause"
          true
        _ ->
          false
      end
    end
  end

end
