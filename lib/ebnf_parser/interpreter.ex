defmodule EbnfInterpreter do

  @doc """
  Most eager interpreter of syntax which we could implement.  This
  consumes all content which was available and tries to match as much
  content as possible.
  """

  def char_for_code( { :character, char } ) do
    char
  end
  def char_for_code( { :hex_character, codepoint } ) do
    <<codepoint::utf8>>
  end

  @doc """
  ## Examples
  Iex> EbnfInterpreter.t_ep( "FOO" )
  ["F", "O", "O" ]
  """
  def t_ep( str ) do
    String.codepoints( str )
  end

  @doc """

  ## Examples

  ## :single_quoted_string and :double_quoted_string

  iex> EbnfInterpreter.eagerly_match_rule( t_ep("FOO"), %{}, {:single_quoted_string, "FOO"}, %{} )
  { :ok, [], "FOO", [] }

  iex> EbnfInterpreter.eagerly_match_rule( t_ep("FOO"), %{}, {:double_quoted_string, "FOO"}, %{} )
  { :ok, [], "FOO", [] }

  iex> EbnfInterpreter.eagerly_match_rule( t_ep("F'O"), %{}, {:single_quoted_string, "F'O"}, %{} )
  { :ok, [], "F'O", [] }

  iex> EbnfInterpreter.eagerly_match_rule( t_ep("F\\\"O"), %{}, {:single_quoted_string, "F\\\"O"}, %{} )
  { :ok, [], "F\\\"O", [] }

  iex> EbnfInterpreter.eagerly_match_rule( t_ep("FOO"), %{}, {:single_quoted_string, "BAR"}, %{} )
  { :fail }

  iex> EbnfInterpreter.eagerly_match_rule( t_ep("FO"), %{}, {:single_quoted_string, "FOO"}, %{} )
  { :fail }


  ## :maybe

  iex> parse_and_match( "'f'?", "f" )
  { :ok, [], "f", [] }

  iex> parse_and_match( "'foo'?", "foo" )
  { :ok, [], "foo", [] }

  iex> parse_and_match( "'foo'?", "fo" )
  { :ok, ["f","o"], "", [] }


  ## :maybe_many

  iex> parse_and_match( "'a'*", "b" )
  { :ok, ["b"], "", [] }

  iex> parse_and_match( "'a'*", "a" )
  { :ok, [], "a", [] }

  iex> parse_and_match( "'a'*", "aba" )
  { :ok, ["b","a"], "a", [] }

  iex> parse_and_match( "'a'*", "aaab" )
  { :ok, ["b"], "aaa", [] }


  ## :one_or_more

  iex> parse_and_match( "'a'+", "a" )
  { :ok, [], "a", [] }

  iex> parse_and_match( "'a'+", "aa" )
  { :ok, [], "aa", [] }

  iex> parse_and_match( "'a'+", "aaa" )
  { :ok, [], "aaa", [] }


  ## :paren_group

  iex> parse_and_match( "('a' 'b')", "ab" )
  { :ok, [], "ab", [] }

  iex> parse_and_match( "('a' 'b')?", "abab" )
  { :ok, ["a","b"], "ab", [] }

  iex> parse_and_match( "('a' 'b')+", "abab" )
  { :ok, [], "abab", [] }

  iex> parse_and_match( "('a' 'b' 'c'?)+", "ababcab" )
  { :ok, [], "ababcab", [] }

  ## :one_of

  iex> parse_and_match( " 'a' | 'b'", "a" )
  { :ok, [], "a", [] }

  iex> parse_and_match( " 'a' | 'b'", "b" )
  { :ok, [], "b", [] }

  iex> parse_and_match( " 'ab' | 'b'", "ab" )
  { :ok, [], "ab", [] }

  iex> parse_and_match( " 'a' | 'ab'", "ab" )
  { :ok, [], "ab", [] }

  iex> parse_and_match( " 'a' | 'b'", "c" )
  { :fail }

  iex> parse_and_match( " 'a' | 'b' | 'c'", "c" )
  { :ok, [], "c", [] }

  iex> parse_and_match( " 'a' | 'b'", "ab" )
  { :ok, ["b"], "a", [] }

  iex> parse_and_match( " ('a' | 'b')* 'c' 'd'+", "abcdd" )
  { :ok, [], "abcdd", [] }

  iex> parse_and_match( " ('a' | 'b')* 'c' 'd'+ 'r'", "abcdd" )
  { :fail }


  ## :range, :bracket_selector and :not_bracket_selector

  iex> parse_and_match( "[a-z]", "1" )
  { :fail }

  iex> parse_and_match( "[0-9]", "1" )
  { :ok, [], "1", [] }

  iex> parse_and_match( "[0-9a-z]", "a" )
  { :ok, [], "a", [] }

  iex> parse_and_match( "[0-9a-z]", "4" )
  { :ok, [], "4", [] }

  iex> parse_and_match( "[0-9a-z]+", "1aboe320" )
  { :ok, [], "1aboe320", [] }

  iex> parse_and_match( "[0-9a-z]+", "á" )
  { :fail }

  iex> parse_and_match( "[^0-9]", "0" )
  { :fail }

  iex> parse_and_match( "'a' [^0-9]", "a" )
  { :fail }

  iex> parse_and_match( "'a' [^0-9]", "aq" )
  { :ok, [], "aq", [] }

  iex> parse_and_match( "[^0-9a-z]+", "ááá" )
  { :ok, [], "ááá", [] }

  iex> parse_and_match( "[^0-9a-z]*", "" )
  { :ok, [], "", [] }


  ## [TODO] :character :hex_character

  ## minus

  iex> parse_and_match( "[a-z] - 'b'", "b" )
  { :fail }

  iex> parse_and_match( "[a-z] - 'b'", "a" )
  { :ok, [], "a", [] }

  iex> parse_and_match( "([a-z] - 'b')+ | [a-z]+", "aabz" )
  { :ok, [], "aabz", [] }

  iex> parse_and_match( "[a-z]+ | ([a-z] - 'b')+", "aabz" )
  { :ok, [], "aabz", [] }

  iex> parse_and_match( "[a-z]* | ([a-z] - 'b')*", "aabz" )
  { :ok, [], "aabz", [] }

  iex> parse_and_match( "([a-z] - 'b')* | [a-z]*", "aabz" )
  { :ok, [], "aabz", [] }


  ## [TODO] :symbol

  """
  def eagerly_match_rule( chars, _syntax, {quote_type, string}, options ) when quote_type in [:single_quoted_string, :double_quoted_string] do

    chars = if Map.get( options, :terminal ) do
      chars
    else
      Enum.drop_while( chars, fn x -> x in [" ","\t","\n"] end )
    end

    if string == to_string( Enum.take( chars, String.length( string ) ) ) do
      chars = Enum.drop( chars, String.length( string ) )
      { :ok, chars, string, [] }
    else
      { :fail }
    end
  end

  # :maybe
  def eagerly_match_rule( chars, syntax, {:maybe, [ matcher ]}, options ) do
    case eagerly_match_rule( chars, syntax, matcher, options ) do
      { :ok, leftover, matched_portion, matched_rule_info } -> { :ok, leftover, matched_portion, matched_rule_info }
      { _ } -> { :ok, chars, "", [] }
    end
  end

  # :maybe_many
  def eagerly_match_rule( chars, syntax, {:maybe_many, [ matcher ]}, options ) do
    case eagerly_match_rule( chars, syntax, matcher, options ) do
      { :ok, leftover, matched_portion, matched_rule_info } ->
        if leftover == chars do
          { :ok, chars, "", matched_rule_info }
        else
          case eagerly_match_rule( leftover, syntax, {:maybe_many, [matcher]}, options ) do
            { :ok, new_leftover, new_matched_portion, next_matched_rule_info } ->
              { :ok, new_leftover, matched_portion <> new_matched_portion, matched_rule_info ++ next_matched_rule_info  }
            { _ } -> { :ok, leftover, matched_portion, matched_rule_info }
          end
        end
      { _ } -> { :ok, chars, "", [] }
    end
  end

  # :one_or_more
  def eagerly_match_rule( chars, syntax, {:one_or_more, [ matcher ]}, options ) do
    case eagerly_match_rule( chars, syntax, matcher, options ) do
      { :ok, leftover, matched_portion, matched_rule_info } ->
        { :ok, new_leftover, next_matched_portion, last_matched_rule_info } = eagerly_match_rule( leftover, syntax, {:maybe_many, [matcher]}, options )
        { :ok, new_leftover, matched_portion <> next_matched_portion, matched_rule_info ++ last_matched_rule_info }
      { _ } -> {:fail}
    end
  end

  # :paren_group
  def eagerly_match_rule( chars, syntax, {:paren_group, contents}, options ) do
    # Match each of the elements in the array
    eagerly_match_rule( chars, syntax, contents, options )
  end

  def eagerly_match_rule( chars, syntax, [ first | rest ], options ) do
    case eagerly_match_rule( chars, syntax, first, options ) do
      { :ok, first_leftover, first_matched_portion, first_rule_info } ->
        case eagerly_match_rule( first_leftover, syntax, rest, options ) do
          { :ok, rest_leftover, rest_matched_portion, rest_rule_info } -> { :ok, rest_leftover, first_matched_portion <> rest_matched_portion, first_rule_info ++ rest_rule_info  }
          { _ } -> { :fail }
        end
      { _ } -> {:fail}
    end
  end
  def eagerly_match_rule( chars, _syntax, [], _options ) do
    { :ok, chars, "", [] }
  end

  # :one_of
  def eagerly_match_rule( chars, syntax, {:one_of, choices}, options ) do
    # In case of options, we should pick the longest solution
    matched_info = Enum.map( choices, fn choice ->  eagerly_match_rule chars, syntax, choice, options end )
    best_choice = Enum.max_by( matched_info,
      fn
        { :ok, _, rest_matched_portion, _ } -> String.length( rest_matched_portion )
        { _ } -> -1
      end )

    best_choice
  end

  # :range
  def eagerly_match_rule( [char | chars], _, {:range, [from_char, to_char]}, _ ) do
    if char_for_code( from_char ) <= char and char <= char_for_code( to_char ) do
      { :ok, chars, char, [] }
    else
      { :fail }
    end
  end
  def eagerly_match_rule( [], _, {:range, _}, _ ) do
    { :fail }
  end

  # :bracket_selector
  def eagerly_match_rule( chars, syntax, {:bracket_selector, [ current_choice | choices ]}, _ ) do
    case eagerly_match_rule( chars, syntax, current_choice, [] ) do
      { :ok, left_chars, matched_portion, matched_rule_info } ->
        { :ok, left_chars, matched_portion, matched_rule_info }
      { _ } ->
        eagerly_match_rule( chars, syntax, {:bracket_selector, choices}, [] )
    end
  end
  def eagerly_match_rule( _, _, {:bracket_selector, [] }, _ ) do
    { :fail }
  end

  # :not_bracket_selector
  def eagerly_match_rule( [], _syntax, {:not_bracket_selector, _}, _ ) do
    { :fail }
  end
  def eagerly_match_rule( chars, syntax, {:not_bracket_selector, [ current_choice | choices ]}, _ ) do
    case eagerly_match_rule( chars, syntax, {:bracket_selector, [current_choice]}, [] ) do
      { :ok, _, _, _ } -> { :fail }
      { :fail } -> eagerly_match_rule( chars, syntax, {:not_bracket_selector, choices}, [] )
    end
  end
  def eagerly_match_rule( [first_char | rest_chars], _syntax, {:not_bracket_selector, []}, _ ) do
    { :ok, rest_chars, first_char, [] }
  end

  # :character :hex_character
  def eagerly_match_rule( [char | chars ], _syntax, {character_type, character}, _ ) when character_type in [:hex_character, :character] do
    if char == char_for_code( {character_type, character} ) do
      { :ok, chars, char, [] }
    else
      { :fail }
    end
  end
  def eagerly_match_rule( [], _, {character_type, _}, _ ) when character_type in [:hex_character, :character] do
    { :fail }
  end

  # :minus
  def eagerly_match_rule( chars, syntax, {:minus, [first, second]}, options ) do
    case eagerly_match_rule( chars, syntax, first, options ) do
      { :ok, leftover, matched_portion, matched_rules } ->
        case eagerly_match_rule( chars, syntax, second, options ) do
          { :ok, _, _, _ } -> { :fail }
          { _ } -> { :ok, leftover, matched_portion, matched_rules }
        end
      { _ } -> { :fail }
    end
  end

  # :symbol
  def eagerly_match_rule( chars, syntax, {:symbol, name}, options ) do
    # Strip spaces from front
    # Match rule
    { terminal, rule } = Map.get( syntax, name )
    chars = if( ( ! Map.get(options, :terminal) ) and terminal ) do
      Enum.drop_while( chars, fn x -> x in [" ","\t","\n"] end )
    else
      chars
    end
    
    new_options = Map.put( options, :terminal, terminal )
    case eagerly_match_rule( chars, syntax, rule, new_options ) do
      {:ok, leftover, matched_portion, matched_rules } -> { :ok, leftover, matched_portion, [{ name, matched_portion, matched_rules }] }
      { _ } -> { :fail }
    end
  end

  def match_named_rule( rule_name, chars, syntax ) do
    # Try to match a named rule.  This needs to update matched_rule_info
    eagerly_match_rule( chars, syntax, {:symbol, rule_name}, %{terminal: false} )
  end


  def match_sparql_rule( rule_name, string ) do
    match_named_rule( rule_name, String.codepoints( string ), Parser.parse_sparql)
  end

end
