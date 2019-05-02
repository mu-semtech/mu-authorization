alias Interpreter.Diff.Template, as: Template
alias Interpreter.Diff, as: Diff
alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word
alias Interpreter.Diff.Variable, as: Variable

defmodule Template do
  defstruct tree_template: nil, array_template: nil, used_solutions: [], score: nil

  # Accessors
  def tree(%Template{tree_template: tree_template}), do: tree_template
  def array(%Template{array_template: array_template}), do: array_template
  def used_solutions(%Template{used_solutions: used_solutions}), do: used_solutions

  @doc """
  Constructs a template from two query solutions.  This is the
  simplest way to create a new template.  Both the array template, as
  well as the variables, will become available.
  """
  def make_template(solution_a, solution_b) do
    case tree_calc(solution_a, solution_b) do
      {:fail} ->
        {:fail}

      tree ->
        %Template{tree_template: tree, used_solutions: [solution_a, solution_b]}
        |> array_calc
        |> cache_score
    end
  end

  @doc """
  Fills the Template based on the received query_string.
  """
  def fill(%Template{array_template: array_template, tree_template: tree_template}, query_string) do
    case fill_array(array_template, query_string) do
      {:fail} ->
        {:fail}

      array ->
        case fill_tree(array, tree_template) do
          {resp, []} -> resp
          # Either non-empty vars, or {:fail}
          _ -> {:fail}
        end
    end
  end

  @doc """
  Appends a solution to the used solutions of this template.
  """
  def add_solution(%Template{used_solutions: solutions} = template, solution) do
    %{template | used_solutions: [solution | solutions]}
  end

  @doc """
  Exhaustively try to calculate a better template based on the
  supplied query_solution.  This may help in incrementally finding
  better templates.
  """
  def exhaustive_better_templates(
        %Template{used_solutions: solutions, tree_template: original_template},
        query_solution
      ) do
    Enum.map(solutions, fn solution ->
      new_template = make_template(solution, query_solution)
      %Template{tree_template: new_tree_template} = new_template

      cond do
        new_tree_template == original_template -> :skip
        array(new_template) == [] -> :skip
        # RE the following two clauses: I'm still in doubt as to
        # whether we should also drop templates with no variables, or
        # whether that's a good situation to have for polling
        # microservices.  Services with only a %Variable{} should be
        # dropped, as there's no speed gain to be gotten from filling
        # them in through this system.
        match?([%Variable{}], array(new_template)) -> :skip
        match?([_], array(new_template)) -> :skip
        true -> new_template
      end
    end)
    |> Enum.reject(fn x -> x == :skip end)
  end

  @doc """
  Sorts an array of templates based on how expensive they will likely be to match
  """
  def sort(templates) do
    templates
    |> Enum.sort_by(
      fn %Template{array_template: [first_arr_elt | _rest]} = template ->
        if is_binary(first_arr_elt) do
          {byte_size(first_arr_elt), score(template)}
        else
          # With the current EBNF and the rejections in
          # exhaustive_better_templates, this case can't happen.
          # However, some bugs could lead to this happening and we'd
          # more likely be on the defensive side in this case.
          # Keeping the system up and running.
          {0, score(template)}
        end
      end,
      &>=/2
    )
  end

  @doc """
  Folds duplicate templates onto each other.
  """
  def fold_duplicates(templates, [limit: limit] \\ [limit: 1000]) do
    Enum.group_by(templates, &tree/1)
    |> Map.values()
    |> Enum.map(fn [template | _] = templates_to_join ->
      all_solutions = Enum.flat_map(templates_to_join, &used_solutions/1)

      new_solutions =
        if Enum.count(all_solutions) > limit do
          Enum.take_random(all_solutions, limit)
        else
          all_solutions
        end

      %{template | used_solutions: new_solutions}
    end)
  end

  def score(%Template{score: score}) when is_number(score), do: score

  def score(%Template{used_solutions: solutions, array_template: var_arr}) do
    total_elements =
      solutions
      |> Enum.map(&element_count/1)
      |> Enum.sum()

    total_elements / (total_elements + Enum.count(solutions) * Enum.count(var_arr))
  end

  @doc """
  Returns the score and yields a template in which the score was set.
  """
  def cached_score(template) do
    score = score(template)
    {score, %{template | score: score}}
  end

  @doc """
  Yields a template in which the score was cached.
  """
  def cache_score(template) do
    template
    |> cached_score
    |> elem(1)
  end

  defp element_count(%InterpreterTerms.SymbolMatch{submatches: submatches})
       when is_list(submatches) do
    child_count =
      submatches
      |> Enum.map(&element_count/1)
      |> Enum.sum()

    child_count + 1
  end

  defp element_count(_) do
    1
  end

  @doc """
  Constructs a template tree from two similar matches.

  For quickly constructing a %Template{} look at make_template
  instead.

  The response consists of a tuple in which the first element contains
  the fixed strings and variable symbols, and the second element
  contains the replaced symbol tree.

  In order to calculate the template, we need to look at our children
  in order to group correctly.  If we are not shallow_same, we will
  invariably fail.  If our children are different, we need to
  construct a template for ourselves with our symbol name.
  """
  def tree_calc(a, b) do
    if Diff.shallow_same?(a, b) do
      case a do
        %Sym{submatches: :none} ->
          a

        %Sym{symbol: sym, submatches: submatches_a} ->
          # We need to figure out that all of our submatches are
          # shallow_same.  If they are, then we can continue to
          # calculate their templates.  Otherwise, we need a variable
          # for our own element.
          %Sym{submatches: submatches_b} = b

          if Enum.count(submatches_a) == Enum.count(submatches_b) do
            all_submatches_shallow_same? =
              [submatches_a, submatches_b]
              |> Enum.zip()
              |> Enum.all?(fn {submatch_a, submatch_b} ->
                Diff.shallow_same?(submatch_a, submatch_b)
              end)

            if all_submatches_shallow_same? do
              child_templates =
                [submatches_a, submatches_b]
                |> Enum.zip()
                |> Enum.map(fn {submatch_a, submatch_b} -> tree_calc(submatch_a, submatch_b) end)

              %Sym{a | submatches: child_templates}
            else
              %Variable{symbol: sym}
            end
          else
            %Variable{symbol: sym}
          end

        %Word{} ->
          a
      end
    else
      {:fail}
    end
  end

  @doc """
  Converts a template tree into a template array.  The template array
  consists of fixed strings, and variables.  With this, an input
  string can be matched to a template string to see if a short and
  fast match can be built.
  """
  def array_calc(%Template{array_template: nil, tree_template: tree_template} = template) do
    %{template | array_template: array_calc(tree_template)}
  end

  def array_calc(%Variable{} = var) do
    [var]
  end

  def array_calc(%Word{word: word, whitespace: whitespace}) do
    [whitespace <> word]
  end

  def array_calc(%Sym{submatches: :none, string: str}) do
    [str]
  end

  def array_calc(%Sym{submatches: submatches, string: str}) do
    # All fixed cases have been implemented above.  This case
    # therefore only needs to cope with grouping the results of its
    # children.  We can append the results of all children, then see
    # if the results can be combined.

    # TODO: this is really based on the current implementation which
    # dumps the whitespace of the current element in front of the
    # string.  For symbol matches, we assume all whitespace is
    # basically ours to consume.  This may become incorrect, but it's
    # the simplest way to get something working now...

    clean_string = String.trim_leading(str)
    whitespace_byte_size = byte_size(str) - byte_size(clean_string)

    <<leading_whitespace::binary-size(whitespace_byte_size), _::binary>> = str

    submatches
    |> Enum.flat_map(&array_calc/1)
    |> Enum.reduce([leading_whitespace], fn item, acc ->
      [first_acc | rest_acc] = acc

      if is_binary(first_acc) && is_binary(item) do
        [first_acc <> item | rest_acc]
      else
        [item | acc]
      end
    end)
    |> Enum.reverse()
  end

  def fill_array([template_constant | template_arr], query_string)
      when is_binary(template_constant) do
    if byte_size(template_constant) <= byte_size(query_string) do
      constant_byte_size = byte_size(template_constant)
      <<query_head::binary-size(constant_byte_size), rest_query_string::binary>> = query_string

      if query_head == template_constant do
        fill_array(template_arr, rest_query_string)
      else
        {:fail}
      end
    else
      {:fail}
    end
  end

  def fill_array([%Variable{symbol: sym} | template_arr], query_string) do
    # The variable symbol is the next thing to match.  We need to
    # select the right portion from our query_string.  It may well be
    # that the first generated answer is not the right one.  We'll
    # still guess on that being the case for now.  Improvements are
    # possible.
    case Parser.parse_query_first(query_string, sym) do
      {string_match, symbol} ->
        match_byte_size = byte_size(string_match)
        <<_::binary-size(match_byte_size), leftover_query_string::binary>> = query_string

        case fill_array(template_arr, leftover_query_string) do
          {:fail} -> {:fail}
          next_fills -> [symbol | next_fills]
        end

      {:fail} ->
        {:fail}
    end
  end

  def fill_array([], query_string) do
    if String.trim(query_string) == "" do
      []
    else
      {:fail}
    end
  end

  def fill_tree(vars, template_tree) do
    case template_tree do
      %Word{} ->
        {template_tree, vars}

      %Variable{} ->
        [var | rest_vars] = vars
        {var, rest_vars}

      %Sym{submatches: :none} ->
        {template_tree, vars}

      %Sym{submatches: submatches} ->
        filled_submatches =
          submatches
          |> Enum.reduce({[], vars}, fn submatch, acc ->
            case acc do
              {prev_submatches, leftover_vars} ->
                case fill_tree(leftover_vars, submatch) do
                  {match, new_leftover_vars} -> {[match | prev_submatches], new_leftover_vars}
                  {:fail} -> {:fail}
                end

              {:fail} ->
                {:fail}
            end
          end)

        case filled_submatches do
          {:fail} ->
            {:fail}

          _ ->
            {child_submatches, leftover_vars} = filled_submatches
            {%{template_tree | submatches: Enum.reverse(child_submatches)}, leftover_vars}
        end
    end
  end
end
