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

end
