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

  def generate_all_options( generator, results\\[] ) do
    case EbnfInterpreter.emit( generator ) do
      { new_state , answer } ->
        generate_all_options( new_state, [ answer | results ] )
      _ -> results
    end
  end

  def smart_all_options( rule, chars, options\\%{} ) do
    rule = Parser.full_parse( rule )
    chars = String.codepoints( chars )
    all_options( rule, chars, options )
  end

  def all_options( rule, chars, options\\%{} ) do
    generator = EbnfInterpreter.make_generator( rule, chars, [], options )
    generate_all_options( generator )
  end

  def longest_match( rule, chars, options\\%{} ) do
    all_options( rule, chars, options )
    |> Enum.max_by( fn({_, matched, _}) -> String.length(matched) end )
  end

  def first_match( rule, chars, options\\%{} ) do
    rule = Parser.full_parse( rule )
    chars = String.graphemes( chars )
    generator = EbnfInterpreter.make_generator( rule, chars, [], options )
    case emit( generator ) do
      { _, result } -> result
      other -> other
    end
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
    # # Try to match a named rule.  This needs to update matched_rule_info
    # eagerly_match_rule( chars, syntax, {:symbol, rule_name}, %{terminal: false} )

    # Try to match a named rule.  This needs to update matched_rule_info
    # make_generator( { :symbol, rule_name }, chars, syntax, %{terminal: false} )
    # |> emit

    rule = {:symbol, rule_name}
    state = %Generator.State{ chars: chars, syntax: syntax }

    EbnfParser.GeneratorConstructor.dispatch_generation( rule, state )
    |> EbnfParser.Generator.emit
  end


  def match_sparql_rule( rule_name, string, include_generator\\false ) do
    response = match_named_rule( rule_name, String.codepoints( string ), Parser.parse_sparql )
    if include_generator do
      response
    else
      case response do
        { :ok, _, result } -> result
        _ -> { :fail }
      end
    end
  end


  @doc """
    Builds a generator for the supplied selector, characters and options.
  """

  # array
  def make_generator( [first_item | rest], chars, syntax, options ) do
    # The list generator will have to generate a result for its first
    # option.  For each of the solutions in the first element of the
    # list, it will have to try all solutions of the child elements.

    first_item_generator = make_generator( first_item, chars, syntax, options )

    { :list, {first_item_generator, rest, syntax, options} }
  end

  def make_generator( [], _chars, _syntax, _options ) do
    { :no_next_step, {} }
  end

  def make_generator( { :paren_group, items }, chars, syntax, options ) do
    make_generator( items, chars, syntax, options )
  end

  # :symbol
  def make_generator( { :symbol, name }, chars, syntax, options ) do
    # Match rule
    { terminal, rule } = Map.get( syntax, name )

    # Strip spaces from front
    chars = if( ( ! Map.get(options, :terminal) ) and terminal ) do
      Enum.drop_while( chars, fn x -> x in [" ","\t","\n"] end )
    else
      chars
    end
    
    # Override terminal option
    new_options = Map.put( options, :terminal, terminal )

    child_generator = make_generator( rule, chars, syntax, new_options )

    { :sub_rule, { name, child_generator } }
  end

  # :one_of
  # def make_generator( { :one_of, choices }, chars, syntax, options ) do
  #   # create a generator for each of the options
  #   { :one_of, Enum.map( choices, &(make_generator( &1, chars, syntax, options )) ) }
  # end

  def make_generator( { :one_of, choices }, chars, syntax, options ) do
    generators = Enum.map( choices, &(make_generator( &1, chars, syntax, options )) )

    { :one_of, generators, [] }
  end

  # :maybe
  def make_generator( { :maybe, [ item ] }, chars, syntax, options ) do
    { :maybe, make_generator( item, chars, syntax, options ), chars }
  end

  # :one_or_more
  def make_generator( { :one_or_more, [ item ] }, chars, syntax, options ) do
    # A: We build a generator for <item>
    #      for each result of generator
    #         Cycle through A
    #      if no result is found
    #        emit result & pop stack

    top_generator = make_generator( item, chars, syntax, options )
    { :one_or_more, { top_generator }, { item, syntax, options } }
  end

  # :maybe_many
  def make_generator( { :maybe_many, [ item ] }, chars, syntax, options ) do
    # A: We build a generator for <item>
    #      for each result of generator
    #         Cycle through A
    #      if no result is found
    #        emit result & pop stack

    { :maybe_many, :go_deeper, [], { item, chars, syntax, options } }
  end

  # this is the standard generator.  if we have no clue what to do,
  # this will give us a standard solution of running
  # eagerly_match_rule.
  def make_generator( rule, chars, syntax, options ) do
    { :eagerly_match, { rule, chars, syntax, options } }
  end


  @doc """
    Emits a result from the generator.  {:fail} is sent if no further results
    are available.

    The output consists of { :new_state, :emitted_result }
  """

  def emit( { :list, { generator, [], _syntax, _options } } ) do
    emit( generator )
  end


  def emit( { :list, { generator, following_rules, syntax, options } } ) do
    build_child_generator = fn (chars) ->
      make_generator( following_rules, chars, syntax, options )
    end

    # get the result from the first generator
    case emit( generator ) do
      { new_first_state, { leftover, matched_portion, matched_rules } } ->
        # for this result
        # => build a generator for all future steps
        child_generator = build_child_generator.( leftover )
        # => try to emit as many results as possible
        emit( { :list_loop, { { new_first_state, child_generator},
                              { matched_portion, matched_rules },
                              { following_rules, syntax, options } } } )
      _ -> { :fail }
    end
  end

  def emit( { :list_loop, { { top_generator, bottom_generator },
                            { top_matched_portion, top_rule_info },
                            { following_rules , syntax, options } } } ) do
    build_child_generator = fn (chars) ->
      make_generator( following_rules, chars, syntax, options )
    end

    # try to get a result from the bottom generator
    case emit( bottom_generator ) do
      { new_bottom_state, { leftover, matched_portion, matched_rules } } ->
        # if we have one, we yield it
        # => adopt our current result and yield a new result
        { { :list_loop, { { top_generator, new_bottom_state }, 
                          { top_matched_portion, top_rule_info },
                          { following_rules, syntax, options } } },
          { leftover, top_matched_portion <> matched_portion, top_rule_info ++ matched_rules } }
      _ -> 
        # if there is no result, try to get a new top_generator result
        case emit( top_generator ) do
          { new_top_state, { leftover, top_matched_portion, top_matched_rules } } ->
            # if there is a top_generator result, build a new child generator
            child_generator = build_child_generator.(leftover)
            # call ourselves with the new child generator
            emit( { :list_loop, { { new_top_state, child_generator },
                                  { top_matched_portion, top_matched_rules },
                                  { following_rules, syntax, options } } } )
          _ -> 
            # if there is no top_generator result, fail
            { :fail }
        end
    end
  end

  # take 1

  # def emit( { :one_of, [] } ) do
  #   {:fail}
  # end

  # def emit( { :one_of, [current|rest] } ) do
  #   case emit( current ) do
  #     { new_state, response } ->
  #       { { :one_of, [ new_state | rest ] },
  #         response }
  #     _ -> emit( { :one_of, rest } )
  #   end
  # end
    
  # take 2

  # def emit( { :one_of, generator, [], _ } ) do
  #   emit( generator )
  # end

  # def emit( { :one_of, generator, [ choice | rest ], { chars, syntax, options } } ) do
  #   case emit( generator ) do
  #     { new_state, result } ->
  #       { { :one_of, new_state, [ choice | rest ], { chars, syntax, options } },
  #         result }
  #     _ ->
  #       generator = make_generator( choice, chars, syntax, options )
  #       emit( { :one_of, generator, rest, { chars, syntax, options } } )
  #   end
  # end

  # take 3

  def emit( { :one_of, [], [] } ) do
    { :fail }
  end

  def emit( { :one_of, generators, [] } ) do
    # filters states which were non-failing
    has_solution = fn item ->
      case item do
        { _, { _, _, _ } } -> true
        _ -> false
      end
    end

    # yields length of match
    length_of_match = fn { _, { _, matched, _ } } ->
      String.length( matched )
    end
      
    # extracts generator state
    get_generator = fn { state, _ } -> state end

    # extract answers
    get_solution = fn { _, solution } -> solution end

    # get sorted results from each generator
    results =
      generators
      |> Enum.map( &emit/1 )
      |> Enum.filter( has_solution )
      |> Enum.sort_by( length_of_match )

    # extract generators and results from each other
    new_generators = Enum.map( results, get_generator )
    new_answers = Enum.map( results, get_solution )

    # launch new emit
    emit( { :one_of, new_generators, new_answers } )
  end

  def emit( { :one_of, generators, [result|other_results] } ) do
    { { :one_of, generators, other_results }, result }
  end


  def emit( { :maybe, generator, characters } ) do
    case emit( generator ) do
      { new_state, response } ->
        { { :maybe, new_state, characters }, response }
      _ ->
        { { :no_next_step, {} },
          { characters, "", [] } }
    end
  end

  def emit( { :one_or_more, { top_generator }, { item, syntax, options } } ) do
    case emit( top_generator ) do
      { new_state, { leftover, matched_portion, matched_rules } } ->
        child_generator = make_generator( { :maybe_many, [item] }, leftover, syntax, options )
        emit( { :one_or_more, { new_state, child_generator },
                { item, matched_portion, matched_rules } } )
      _ -> { :fail }
    end
  end


  def emit( { :one_or_more, { top_state, child_state },
              { item, matched_portion, matched_rules } } ) do
    case emit( child_state ) do
      { new_child_state, { new_leftover, new_matched_portion, new_matched_rules } } ->
        { { :one_or_more, { top_state, new_child_state }, { item, matched_portion, matched_rules } },
          { new_leftover, matched_portion <> new_matched_portion, matched_rules ++ new_matched_rules } }
      _ ->
        emit( { :one_or_more, { top_state },
                { item, matched_portion, matched_rules } } )
    end
  end

  # def emit( { :one_or_more, :recycle, [], _ } ) do
  #   { :fail }
  # end

  # def emit( { :one_or_more, :go_deeper,
  #             [ { top_state, leftover, matched_portion, matched_rules } | rest ],
  #             { item, syntax, options } } ) do
  #   generator = make_generator( item, leftover, syntax, options )
  #   case emit( generator ) do
  #     { new_state, {new_leftover, new_matched_portion, new_matched_rules} } ->
  #       emit( { :one_or_more, :go_deeper,
  #               [ { new_state, { new_leftover, matched_portion <> new_matched_portion, matched_rules ++ new_matched_rules } }, { top_state, leftover, matched_portion, matched_rules } | rest ],
  #               { item, syntax, options } } )
  #     _ ->
  #       { { :one_or_more, :recycle,
  #           [ { top_state, leftover, matched_portion, matched_rules } | rest ],
  #           { item, syntax, options } },
  #         { leftover, matched_portion, matched_rules } }
  #   end
  # end

  # def emit( { :one_or_more, :recycle,
  #             [ { top_state, _leftover, _matched_portion, _matched_rules } | rest ],
  #             { item, syntax, options } } ) do
  #   case emit( top_state ) do
  #     { new_state, {new_leftover, new_matched_portion, new_matched_rules} } ->
  #       emit( { :one_or_more, :go_deeper,
  #               # new_matched_portion is supposedly incorrect still.
  #               # It needs to take the previously matched portion into
  #               # account of one level higher up the stack.
  #               [ { new_state, new_leftover, new_matched_portion, new_matched_rules } | rest ],
  #               { item, syntax, options } } )
  #     _ ->
  #       { :one_or_more, :recycle,
  #         rest,
  #         { item, syntax, options } }
  #   end
  # end

  def emit( { :maybe_many, :go_deeper, [], { item, chars, syntax, options } } ) do
    generator = make_generator( item, chars, syntax, options )
    case emit( generator ) do
      { top_state, {top_leftover, matched_portion, matched_rules} } ->
        emit( { :maybe_many, :go_deeper,
                [ { top_state, { top_leftover, matched_portion, matched_rules } } ],
                { item, chars, syntax, options } } )
      _ ->
        { { :no_next_step, {} },
          { chars, "", [] } }
    end
  end

  def emit( { :maybe_many, :go_deeper,
              [ { top_state, { top_leftover, matched_portion, matched_rules } } | rest ],
              { item, chars, syntax, options } } ) do
    generator = make_generator( item, top_leftover, syntax, options )
    case emit( generator ) do
      { state, {leftover, new_match, new_rules} } ->
        emit( { :maybe_many, :go_deeper,
                # new_matched_portion is supposedly incorrect still.
                # It needs to take the previously matched portion into
                # account of one level higher up the stack.
                [ { state, { leftover, matched_portion <> new_match, matched_rules ++ new_rules } },
                  { top_state, { top_leftover, matched_portion, matched_rules } }
                  | rest ],
                { item, chars, syntax, options } } )
      _ ->
        { { :maybe_many, :recycle,
            [ { top_state, { top_leftover, matched_portion, matched_rules } } | rest ],
            { item, chars, syntax, options } },
          { top_leftover, matched_portion, matched_rules } }
    end
  end

  def emit( { :maybe_many, :recycle, [], { _item, chars, _syntax, _options } } ) do
    { { :no_next_step, {} },
      { chars, "", [] } }
  end

  def emit( { :maybe_many, :recycle,
              [ { top_state, { top_leftover, matched_portion, matched_rules } } | rest ],
              { item, chars, syntax, options } } ) do
    case emit( top_state ) do
      { state, {leftover, new_match, new_rules} } ->
        emit( { :maybe_many, :go_deeper,
                # new_matched_portion is supposedly incorrect still.
                # It needs to take the previously matched portion into
                # account of one level higher up the stack.
                [ { state, { leftover, matched_portion <> new_match, matched_rules ++ new_rules } },
                  { top_state, { top_leftover, matched_portion, matched_rules } }
                  | rest ],
                { item, chars, syntax, options } } )
      _ ->
        { { :maybe_many, :recycle,
            rest,
            { item, chars, syntax, options } },
          { top_leftover, matched_portion, matched_rules } }
    end
  end


    
  # The simplest emission is that what eagerly_match_rule returned
  def emit( { :eagerly_match, { rule, chars, syntax, options} } ) do
    case eagerly_match_rule( chars, syntax, rule, options ) do
      { :ok, leftover, matched_portion, matched_rules } ->
        { { :no_next_step, {} }, { leftover, matched_portion, matched_rules } }
      _ ->
        { :fail }
    end
  end

  def emit( { :sub_rule, { name, child_generator } } ) do
    case emit(child_generator) do
      { next_generator_state, { leftover, matched_portion, matched_rules } } ->
        { { :sub_rule, { name, next_generator_state } },
          { leftover, matched_portion, [{ name, matched_portion, matched_rules }] }
        }
      _ ->
        { :fail }
    end
  end

  def emit( { :no_next_step, _ } ) do
    { :fail }
  end

end
