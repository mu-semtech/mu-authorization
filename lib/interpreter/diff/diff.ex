alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word
alias Interpreter.Diff.Variable, as: Variable

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

  @doc """
  Constructs a template tree from two similar matches.

  The response consists of a tuple in which the first element contains
  the fixed strings and variable symbols, and the second element
  contains the replaced symbol tree.

  In order to calculate the template, we need to look at our children
  in order to group correctly.  If we are not shallow_same, we will
  invariably fail.  If our children are different, we need to
  construct a template for ourselves with our symbol name.
  """
  def template_tree_calc( a, b ) do
    if shallow_same?( a, b ) do
      case a do
        %Sym{ submatches: :none } -> a
        %Sym{ symbol: sym, submatches: submatches_a } ->
          # We need to figure out that all of our submatches are
          # shallow_same.  If they are, then we can continue to
          # calculate their templates.  Otherwise, we need a variable
          # for our own element.
          %Sym{ submatches: submatches_b } = b
          if Enum.count( submatches_a ) == Enum.count( submatches_b ) do
            all_submatches_shallow_same? =
              [submatches_a, submatches_b]
              |> Enum.zip
              |> Enum.all?( fn ({submatch_a, submatch_b}) -> shallow_same?( submatch_a, submatch_b ) end )

            if all_submatches_shallow_same? do
              child_templates =
                [submatches_a, submatches_b]
                |> Enum.zip
                |> Enum.map( fn({submatch_a, submatch_b}) -> template_tree_calc( submatch_a, submatch_b ) end )

              %Sym{ a | submatches: child_templates }
            else
              %Variable{ symbol: sym }
            end
          else
            %Variable{ symbol: sym }
          end
        %Word{} -> a
      end
    else
      { :fail }
    end
  end

  @doc """
  Converts a template_tree into a template array.  The template array
  consists of fixed strings, and variables.  With this, an input
  string can be matched to a template string to see if a short and
  fast match can be built.
  """
  def template_calc( %Variable{} = var ) do
    [var]
  end
  def template_calc( %Word{ word: word, whitespace: whitespace } ) do
    [whitespace <> word]
  end
  def template_calc( %Sym{ submatches: :none, string: str } ) do
    [str]
  end
  def template_calc( %Sym{ submatches: submatches, string: str } ) do
    # All fixed cases have been implemented above.  This case
    # therefore only needs to cope with grouping the results of its
    # children.  We can append the results of all children, then see
    # if the results can be combined.

    # TODO: this is really based on the current implementation which
    # dumps the whitespace of the current element in front of the
    # string.  For symbol matches, we assume all whitespace is
    # basically ours to consume.  This may become incorrect, but it's
    # the simplest way to get something working now...

    clean_string = String.trim_leading( str )
    whitespace_byte_size = byte_size( str ) - byte_size( clean_string )

    <<leading_whitespace::binary-size(whitespace_byte_size),_::binary>> = str

    submatches
    |> Enum.flat_map( &template_calc/1 )
    |> Enum.reduce( [leading_whitespace], fn (item, acc) ->
      [first_acc|rest_acc] = acc
      if is_binary( first_acc ) && is_binary( item ) do
        [first_acc <> item | rest_acc]
      else
        [item | acc]
      end
    end )
    |> Enum.reverse
  end

  def fill_template_arr( [template_constant|template_arr], query_string ) when is_binary( template_constant ) do
    # IO.puts "string match"
    # IO.inspect query_string, label: "Query string"
    # IO.inspect template_constant, label: "Template constant"
    constant_byte_size = byte_size(template_constant)
    <<query_head::binary-size(constant_byte_size),rest_query_string::binary>> = query_string

    if query_head == template_constant do
      fill_template_arr( template_arr, rest_query_string )
    else
      # IO.puts "Could not match head"
      # IO.inspect query_head, label: "Query head to match"
      # IO.inspect template_constant, label: "template constant to match"
      {:fail}
    end
  end
  def fill_template_arr( [%Variable{symbol: sym}|template_arr], query_string ) do
    # The variable symbol is the next thing to match.  We need to
    # select the right portion from our query_string.  It may well be
    # that the first generated answer is not the right one.  We'll
    # still guess on that being the case for now.  Improvements are
    # possible.
    # IO.puts "symbol match"
    case Parser.parse_query_first( query_string, sym ) do
      { string_match, symbol } ->
        match_byte_size = byte_size(string_match)
        <<_::binary-size(match_byte_size),leftover_query_string::binary>> = query_string
        [symbol|fill_template_arr(template_arr, leftover_query_string)]
      { :fail } -> {:fail}
    end
  end
  def fill_template_arr( [], query_string ) do
    # IO.puts "empty match"
    if String.trim(query_string) == "" do
      []
    else
      # IO.inspect( query_string, label: "Failing match b/c leftover portion:" )
      {:fail}
    end
  end

  def fill_template_tree( vars, template_tree ) do
    case template_tree do
      %Word{} -> { template_tree, vars }
      %Variable{} ->
        [var|rest_vars] = vars
        { var, rest_vars }
      %Sym{ submatches: :none } -> { template_tree, vars }
      %Sym{ submatches: submatches } ->
        { child_submatches, leftover_vars } =
          submatches
          |> Enum.reduce( {[],vars}, fn (submatch, {prev_submatches,leftover_vars} ) ->
              { match, new_leftover_vars } = fill_template_tree( leftover_vars, submatch )
              { [ match | prev_submatches ], new_leftover_vars }
             end )
        { %{ template_tree | submatches: Enum.reverse(child_submatches) }, leftover_vars }
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
