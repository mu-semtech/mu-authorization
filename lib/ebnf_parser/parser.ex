defmodule EbnfParser.Parser do
  @doc """
  Tokenizes and parses an EBNF string into an understood format

  ## Examples

      iex> tap( "iri | 'a' | ( '!' PathNegatedPropertySet ) | ('(' Path ')')" )
      [ one_of: [
          symbol: :iri,
          single_quoted_string: "a",
          paren_group: [
            single_quoted_string: "!",
            symbol: :PathNegatedPropertySet
          ],
          paren_group: [
            single_quoted_string: "(",
            symbol: :Path,
            single_quoted_string: ")"
          ]
        ]
      ]
  """
  def tokenize_and_parse(string) do
    string
    |> EbnfParser.Tokenizer.tokenize()
    |> smart_ebnf_parser

    # |> EbnfParser.Parser.ebnf_parser
    # |> Enum.reverse
    # |> ( Enum.map &EbnfParser.Parser.ebnf_parser_reverse_order/1 )
  end

  def by_protocol(ebnf_string, match_string) do
    ebnf = tokenize_and_parse(ebnf_string)
    state = %Generator.State{chars: String.graphemes(match_string)}
    EbnfParser.GeneratorConstructor.dispatch_generation(ebnf, state)
  end

  def all_results(generator, prev_results \\ []) do
    case EbnfParser.Generator.emit(generator) do
      {:ok, gen, res} -> all_results(gen, [res | prev_results])
      _ -> prev_results
    end
  end

  def ebnf_parser_reverse_order({name, [a | rest]}) do
    updated_content =
      [a | rest]
      |> Enum.reverse()
      |> Enum.map(&ebnf_parser_reverse_order/1)

    {name, updated_content}
  end

  def ebnf_parser_reverse_order({name, content}) do
    {name, content}
  end

  def ebnf_parser_reverse_order(item) do
    item
  end

  def ebnf_parser_append_to_parent(content, [{parent_group, parent_content} | other_parents]) do
    [{parent_group, [content | parent_content]} | other_parents]
  end

  # Smart parser for EBNF syntax
  #
  # Groups logical syntax so it's easy to understand in multiple steps.
  # - Single tokens
  # - Parens
  # - Counts (+, * and ?)
  # - Infixes (or and minus)
  def smart_ebnf_parser(tokens) do
    tokens
    |> smart_parse_single_tokens({:default})
    |> smart_parse_parens([])
    |> smart_parse_counts
    |> smart_parse_infixes
  end

  @doc """
  Reverses the list, and the lists inside of the list recursively.

  ## Examples
      iex> EbnfParser.Parser.smart_reverse_inside( [:foo] )
      [:foo]

      iex> EbnfParser.Parser.smart_reverse_inside( [:foo, :bar] )
      [:bar, :foo]

      iex> EbnfParser.Parser.smart_reverse_inside( [{:foo, :bar}, {:baz}] )
      [{:baz}, {:foo, :bar}]

      iex> EbnfParser.Parser.smart_reverse_inside( [{:two, [:five, :four, [:three]]}, {:one}] )
      [{:one}, {:two, [[:three], :four, :five]}]
  """
  def smart_reverse_inside(list) when is_list(list) do
    smart_reverse_inside(list, [])
  end

  def smart_reverse_inside([], processed) do
    processed
  end

  def smart_reverse_inside([{name, list} | rest], processed) when is_list(list) do
    smart_reverse_inside(rest, [{name, smart_reverse_inside(list)} | processed])
  end

  def smart_reverse_inside([token | rest], processed) do
    smart_reverse_inside(rest, [token | processed])
  end

  @doc """
  Parses sinlge tokens out of a set of content


  """
  # No content left
  def smart_parse_single_tokens([], {:default}) do
    []
  end

  # { :symbol, string }
  def smart_parse_single_tokens([{:symbol, string} | rest], status) do
    [{:symbol, string} | smart_parse_single_tokens(rest, status)]
  end

  # { :comment }
  def smart_parse_single_tokens([{:comment, _string} | rest], status) do
    smart_parse_single_tokens(rest, status)
  end

  # { :double_quote, string }
  def smart_parse_single_tokens([{:double_quote, string} | rest], status) do
    [{:double_quoted_string, string} | smart_parse_single_tokens(rest, status)]
  end

  # { :single_quote, string }
  def smart_parse_single_tokens([{:single_quote, string} | rest], status) do
    [{:single_quoted_string, string} | smart_parse_single_tokens(rest, status)]
  end

  # { :open_bracket }
  def smart_parse_single_tokens([{:open_bracket}, {:negation} | other_input], _) do
    smart_parse_single_tokens(other_input, {{:in_bracket}, {:negation}, []})
  end

  def smart_parse_single_tokens([{:open_bracket} | other_input], _) do
    smart_parse_single_tokens(other_input, {{:in_bracket}, {:positive}, []})
  end

  # { :character, char }
  def smart_parse_single_tokens([{:character, char} | rest], {{:in_bracket}, kind, arr}) do
    smart_parse_single_tokens(rest, {{:in_bracket}, kind, [{:character, char} | arr]})
  end

  # { :hex_character, value }
  def smart_parse_single_tokens([{:hex_character, value} | rest], {{:in_bracket}, kind, arr}) do
    smart_parse_single_tokens(rest, {{:in_bracket}, kind, [{:hex_character, value} | arr]})
  end

  # { :range }
  def smart_parse_single_tokens(
        [{:range}, end_char_block | rest],
        {{:in_bracket}, kind, [prev | rest_prevs]}
      ) do
    smart_parse_single_tokens(
      rest,
      {{:in_bracket}, kind, [{:range, [prev, end_char_block]} | rest_prevs]}
    )
  end

  # { :close_bracket }
  def smart_parse_single_tokens([{:close_bracket} | rest], {{:in_bracket}, kind, content}) do
    name =
      case kind do
        {:negation} -> :not_bracket_selector
        {:positive} -> :bracket_selector
      end

    [{name, Enum.reverse(content)} | smart_parse_single_tokens(rest, {:default})]
  end

  def smart_parse_single_tokens([token | rest], {:default}) do
    [token | smart_parse_single_tokens(rest, {:default})]
  end

  @doc """
  Puts parens into groups of single tokens.
  """
  def smart_parse_parens([{:open_paren} | rest], parents) do
    smart_parse_parens(rest, [{:paren, []} | parents])
  end

  def smart_parse_parens([{:close_paren} | rest], [
        {:paren, content},
        {:paren, parent_content} | parents
      ]) do
    smart_parse_parens(rest, [
      {:paren, [{:paren_group, Enum.reverse(content)} | parent_content]} | parents
    ])
  end

  def smart_parse_parens([{:close_paren} | rest], [{:paren, content} | parents]) do
    [{:paren_group, Enum.reverse(content)} | smart_parse_parens(rest, parents)]
  end

  def smart_parse_parens([item | rest], [{:paren, content} | parents]) do
    smart_parse_parens(rest, [{:paren, [item | content]} | parents])
  end

  def smart_parse_parens([token | rest], parents) do
    [token | smart_parse_parens(rest, parents)]
  end

  def smart_parse_parens([], []) do
    []
  end

  @doc """
  Parses counts (plus, star and question_mark)
  """
  def smart_parse_counts([elt, {symbol} | rest]) when symbol in [:star, :plus, :question_mark] do
    group_name =
      case symbol do
        :star -> :maybe_many
        :plus -> :one_or_more
        :question_mark -> :maybe
      end

    [{group_name, smart_parse_counts([elt])} | smart_parse_counts(rest)]
  end

  def smart_parse_counts([{:paren_group, items} | rest]) do
    [{:paren_group, smart_parse_counts(items)} | smart_parse_counts(rest)]
  end

  def smart_parse_counts([unknown_item | rest]) do
    [unknown_item | smart_parse_counts(rest)]
  end

  def smart_parse_counts([]) do
    []
  end

  @doc """
  Splits a list by a specified value

  iex> EbnfParser.Parser.split_by( [1,2,3,4], 3 )
  [[1,2],[4]]

  iex> EbnfParser.Parser.split_by( [1, 2, { :foo }, 4, 5], {:foo} )
  [[1,2],[4,5]]

  iex> EbnfParser.Parser.split_by( [1, 2, { :foo }, 4, 5, { :foo }, 6, 7], {:foo} )
  [[1,2],[4,5], [6,7]]
  """
  def split_by(enum, item) do
    split_by(enum, item, [[]])
  end

  def split_by([value | rest], value, groups) do
    split_by(rest, value, [[] | groups])
  end

  def split_by([item | rest], value, [current_group | groups]) do
    split_by(rest, value, [[item | current_group] | groups])
  end

  def split_by([], _, collection) do
    collection
    |> Enum.reverse()
    |> Enum.map(&Enum.reverse/1)
  end

  @doc """
  Parses infixes ( minus and pipe )

  iex> EbnfParser.Parser.smart_parse_infixes( [ :foo, { :pipe }, :bar ] )
  [ { :one_of, [ :foo, :bar ] } ]

  iex> EbnfParser.Parser.smart_parse_infixes( [ :foo, { :pipe }, :bar, { :pipe }, :baz ] )
  [ { :one_of, [ :foo, :bar, :baz ] } ]

  iex> EbnfParser.Parser.smart_parse_infixes( [ :foo, { :pipe }, :bar, :baz ] )
  [ one_of: [ :foo, paren_group: [:bar, :baz] ] ]
  iex> EbnfParser.Parser.smart_parse_infixes( [ :foo, { :pipe }, :bar, { :pipe }, :baz, :bang ] )
  [ { :one_of, [ :foo, :bar, {:paren_group, [:baz, :bang] } ] } ]

  iex> EbnfParser.Parser.smart_parse_infixes( [ :foo, { :pipe }, :bar, { :pipe }, :baz, :bang, { :pipe }, :bing ] )
  [ { :one_of, [ :foo, :bar, {:paren_group, [:baz, :bang]}, :bing ] } ]

  iex> EbnfParser.Parser.smart_parse_infixes( [ :foo, :bar, { :pipe }, :baz, :bongo ] )
  [ { :one_of, [ paren_group: [:foo, :bar], paren_group: [:baz, :bongo] ] } ]

  """
  def smart_parse_infixes(enum) when is_list(enum) do
    case split_by(enum, {:pipe}) do
      [_no_pipe] ->
        case split_by(enum, {:minus}) do
          [no_minus] ->
            Enum.map(no_minus, &smart_parse_infixes/1)

          [minus_left, minus_right] ->
            transform_side = fn
              [side] -> smart_parse_infixes(side)
              side -> {:paren_group, smart_parse_infixes(side)}
            end

            [{:minus, [transform_side.(minus_left), transform_side.(minus_right)]}]

          _ ->
            raise "Too many parts given to minus"
        end

      yes_pipe ->
        [
          {:one_of,
           Enum.map(
             yes_pipe,
             fn
               [x] ->
                 [res] = smart_parse_infixes([x])
                 res

               x ->
                 {:paren_group, smart_parse_infixes(x)}
             end
           )}
        ]
    end
  end

  def smart_parse_infixes([{token, items} | rest])
      when token in [:paren_group, :maybe_many, :one_or_more, :maybe] do
    [{token, smart_parse_infixes(items)} | smart_parse_infixes(rest)]
  end

  def smart_parse_infixes({token, items})
      when token in [:paren_group, :maybe_many, :one_or_more, :maybe] do
    {token, smart_parse_infixes(items)}
  end

  def smart_parse_infixes([]) do
    []
  end

  def smart_parse_infixes(token) do
    token
  end
end
