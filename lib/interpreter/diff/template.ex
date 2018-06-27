alias Interpreter.Diff.Template, as: Template
alias Interpreter.Diff, as: Diff
alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word
alias Interpreter.Diff.Variable, as: Variable

defmodule Template do
  defstruct [:tree_template, :array_template, {:used_solutions,[]}]

  # Accessors
  def tree( %Template{ tree_template: tree_template }), do: tree_template
  def array( %Template{ array_template: array_template }), do: array_template

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
  def tree_calc( a, b ) do
    if Diff.shallow_same?( a, b ) do
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
              |> Enum.all?( fn ({submatch_a, submatch_b}) -> Diff.shallow_same?( submatch_a, submatch_b ) end )

            if all_submatches_shallow_same? do
              child_templates =
                [submatches_a, submatches_b]
                |> Enum.zip
                |> Enum.map( fn({submatch_a, submatch_b}) -> tree_calc( submatch_a, submatch_b ) end )

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
  Converts a template tree into a template array.  The template array
  consists of fixed strings, and variables.  With this, an input
  string can be matched to a template string to see if a short and
  fast match can be built.
  """
  def array_calc( %Variable{} = var ) do
    [var]
  end
  def array_calc( %Word{ word: word, whitespace: whitespace } ) do
    [whitespace <> word]
  end
  def array_calc( %Sym{ submatches: :none, string: str } ) do
    [str]
  end
  def array_calc( %Sym{ submatches: submatches, string: str } ) do
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
    |> Enum.flat_map( &array_calc/1 )
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

  def fill_array( [template_constant|template_arr], query_string ) when is_binary( template_constant ) do
    if byte_size(template_constant) <= byte_size( query_string ) do
      constant_byte_size = byte_size(template_constant)
      <<query_head::binary-size(constant_byte_size),rest_query_string::binary>> = query_string

      if query_head == template_constant do
        fill_array( template_arr, rest_query_string )
      else
        {:fail}
      end
    else
      {:fail}
    end
  end
  def fill_array( [%Variable{symbol: sym}|template_arr], query_string ) do
    # The variable symbol is the next thing to match.  We need to
    # select the right portion from our query_string.  It may well be
    # that the first generated answer is not the right one.  We'll
    # still guess on that being the case for now.  Improvements are
    # possible.
    case Parser.parse_query_first( query_string, sym ) do
      { string_match, symbol } ->
        match_byte_size = byte_size(string_match)
        <<_::binary-size(match_byte_size),leftover_query_string::binary>> = query_string
        case fill_array(template_arr, leftover_query_string) do
          { :fail } -> { :fail }
          next_fills -> [symbol|next_fills]
        end
      { :fail } -> {:fail}
    end
  end
  def fill_array( [], query_string ) do
    if String.trim(query_string) == "" do
      []
    else
      {:fail}
    end
  end

  def fill_tree( vars, template_tree ) do
    case template_tree do
      %Word{} -> { template_tree, vars }
      %Variable{} ->
        [var|rest_vars] = vars
        { var, rest_vars }
      %Sym{ submatches: :none } -> { template_tree, vars }
      %Sym{ submatches: submatches } ->
        { child_submatches, leftover_vars } =
          submatches
          |> Enum.reduce( {[],vars}, fn (submatch, acc ) ->
            case acc do
              {prev_submatches,leftover_vars} ->
                case fill_tree( leftover_vars, submatch ) do
                  { match, new_leftover_vars } -> { [ match | prev_submatches ], new_leftover_vars }
                  { :fail } -> { :fail }
                end
              {:fail} -> {:fail}
            end
            end )
        { %{ template_tree | submatches: Enum.reverse(child_submatches) }, leftover_vars }
    end
  end
end
