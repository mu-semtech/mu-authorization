alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word

defmodule Interpreter.Diff do
  def similarity( a, b ) do
    { matching, total } = similarity_calc( a, b )
    matching / total
  end

  @doc """
  Returns a similarity number.  Comparing how similar the two objects
  are.

  We compare this by looking at the amount of terms in the query, and
  seeing how much they overlap.

  The matching is returned as a tuple containing the total amount of
  positive similarities as the first value, and the total amount of
  compared similarities as the second value.

  @return { positive_similaties, total_similarities }
  """
  def similarity_calc( %Sym{ submatches: asub } = a, %Sym{ submatches: bsub } = b ) do
    if shallow_same?( a, b ) do
      { self_positive_similarities, self_total_similarities } = { 1, 1 }

      asub = if asub == :none do [] else asub end
      bsub = if bsub == :none do [] else bsub end

      longest_length = max( Enum.count( asub ), Enum.count( bsub ) )
      shortest_length = min( Enum.count( asub ), Enum.count( bsub ) )

      { sub_positive_similarities, sub_total_similarities } =
        [ asub, bsub ]
        |> Enum.zip
        |> Enum.reduce( {0,0}, fn (sub_elts, acc_similarities) ->
          {asub_elt, bsub_elt} = sub_elts
          { positive_similarities, total_similarities } = acc_similarities
          {add_pos, add_total} = similarity_calc( asub_elt, bsub_elt )
          {positive_similarities + add_pos, total_similarities + add_total}
        end )

      { missing_matches_positive_similarities, missing_matches_total_similarities } =
        { 0, longest_length - shortest_length }

      { self_positive_similarities + sub_positive_similarities + missing_matches_positive_similarities,
        self_total_similarities + sub_total_similarities + missing_matches_total_similarities }
    else
      { 0, 1 }
    end
  end
  def similarity_calc( a, b ) do
    if shallow_same?( a, b ) do
      { 1, 1 }
    else
      { 0, 1 }
    end
  end

  def shallow_same?( %Sym{ symbol: a, submatches: :none, string: str_a }, %Sym{ symbol: a, submatches: :none, string: str_b } ) do
    str_a == str_b
  end
  def shallow_same?( %Sym{ symbol: a , whitespace: whitespace }, %Sym{ symbol: a , whitespace: whitespace } ) do
    true
  end
  def shallow_same?( %Sym{ symbol: a, whitespace: _whitespace_one }, %Sym{ symbol: a, whitespace: _whitespace_two } ) do
    # Symbols with different whitespace are different.

    # TODO: merge with the last clause?  this will basically fall
    # through to there.
    false
  end
  def shallow_same?( %Word{ word: word, whitespace: whitespace }, %Word{ word: word, whitespace: whitespace } ) do
    true
  end
  def shallow_same?( _, _ ) do
    false
  end
end
