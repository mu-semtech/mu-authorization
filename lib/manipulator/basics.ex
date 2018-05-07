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
      { :insert_after, content } ->
        { :insert_after, content }
      { :continue } ->
        map_submatches( result, functor )
    end
  end

  def map_submatches( %InterpreterTerms.SymbolMatch{ submatches: submatches } = symbolmatch, functor )
  when is_list( submatches ) do
    %{ symbolmatch |
       submatches: Enum.flat_map( submatches,
         fn (sub) ->
           res = map_matches( sub, functor )
           case res do
             { :insert_after, elt } ->
               [ sub, elt ]
             _ ->
               [ res ]
           end
         end ) }
  end

  def map_submatches( symbol, _ ) do
    symbol
  end

end
