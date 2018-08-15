defmodule Manipulators.Basics do
  @doc """
  Walks the results recursively, until requested to stop.
  Receives one state and is allowed to emit an array of states to
  replace it.
  """
  def map_matches( result, functor ) do
    case functor.( result ) do
      { :replace_by, content } ->
        content
      { :replace_and_traverse, content } ->
        map_submatches( content, functor )
      { :insert_after, content } ->
        { :insert_after, content }
      { :continue } ->
        map_submatches( result, functor )
      { :skip } ->
        result
      { :exit, value } ->
        { :exit, value }
    end
  end

  def map_submatches( %InterpreterTerms.SymbolMatch{ submatches: submatches } = symbolmatch, functor )
  when is_list( submatches ) do
    case (
      submatches
      |> Enum.reduce_while( [],
         fn (sub, acc) ->
           res = map_matches( sub, functor )
           case res do
             { :insert_after, elt } ->
               new_acc = [[sub,elt] | acc]
               { :continue, new_acc }
             { :exit, value } ->
               { :halt, { :exit, value } }
             _ ->
               { :cont, [[ res ] | acc] }
           end
         end ) )
    do
      { :exit, value } ->
        { :exit, value }
      submatches ->
        new_submatches =
          submatches
          |> Enum.reverse
          |> Enum.flat_map( &(&1) )

        %{ symbolmatch
           | submatches: new_submatches }
    end
  end

  def map_submatches( symbol, _ ) do
    symbol
  end



  @doc """

  Walks the results recursively, until requested to stop.  Behaves in
  the same way as map_matches, but remembers the state.

  Note that some keywords are currently not allowed as state, as their
  terms are used internally.  Namely :replace_by, :skip,
  :insert_after, :exit, :continue, :replace_and_traverse.

  # TODO: remove shared code with map_matches
  """
  def map_matches_with_state( start_state, result, functor ) do
    case functor.( start_state, result ) do
      # State yielding options
      { :replace_by, new_state, content } ->
        { new_state, content }
      { :skip, new_state } ->
        { new_state, result }
      # Tree operations
      { :insert_after, new_state, content } ->
        { :insert_after, new_state, content }
      { :exit, new_state, value } ->
        { :exit, new_state, value }
      # Dispatch to submatches
      { :continue, new_state } ->
        map_submatches_with_state( new_state, result, functor )
      { :replace_and_traverse, new_state, content } ->
        map_submatches_with_state( new_state, content, functor )
    end
  end

  # TODO: remove shared code with map_submatches
  def map_submatches_with_state( state, %InterpreterTerms.SymbolMatch{ submatches: submatches } = symbolmatch, functor )
  when is_list( submatches ) do
    case (
      # Use reduce_while so we can exit early when requested
      submatches
      |> Enum.reduce_while( {state,[]},
         fn (sub, {state,acc}) ->
           res = map_matches_with_state( state, sub, functor )
           case res do
             { :insert_after, new_state, elt } ->
               new_acc = { new_state, [[sub,elt] | acc] }
               { :continue, new_acc }
             { :exit, new_state, value } ->
               { :halt, { :exit, new_state, value } }
             { new_state, new_result } ->
               { :cont, { new_state, [[ new_result ] | acc] } }
           end
         end ) )
    do
      # If we had to short-circuit due to exit, exit
      { :exit, state, value } ->
        { :exit, state, value }
      # Otherwise use the submatches to yield the new result
      { new_state, submatches } ->
        new_submatches =
          submatches
          |> Enum.reverse
          |> Enum.flat_map( &(&1) )

      { new_state,
        %{ symbolmatch
           | submatches: new_submatches } }
    end
  end

  def map_submatches_with_state( state, symbol, _ ) do
    { state, symbol }
  end

end
