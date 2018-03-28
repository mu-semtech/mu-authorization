defmodule EbnfParser.Tokenizer do
# These symbols may be combined to match more complex patterns as follows, where A and B represent simple expressions: 

# A B
#  matches A followed by B. This operator has higher precedence than alternation; thus A B | C D is identical to (A B) | (C D).

  # def ebnf_tokenizer( {:state}, content_array )

  # whitespace
  def ebnf_tokenizer( { :default }, [ symbol | rest ] ) when symbol in [" ", "\n", "\t"] do
    ebnf_tokenizer( { :default }, rest )
  end

  # Symbol
  @doc """
  ## Examples
       iex> Parser.ebnf_tokenizer( {:default}, String.codepoints("FOO") )
       [ {:symbol, :FOO } ]
  """
  def ebnf_tokenizer( {:default} , [ char | rest ] ) when ("a" <= char and char <= "z") or ("A" <= char and char <= "Z") do
    ebnf_tokenizer( {:symbol, [ char ] }, rest )
  end

  def ebnf_tokenizer( {:symbol, chars} , [ char | rest ] ) when ("a" <= char and char <= "z") or ("A" <= char and char <= "Z") or ("0" <= char and char <= "9") or (char == "_") do
    ebnf_tokenizer( {:symbol, [ char | chars ] }, rest )
  end

  def ebnf_tokenizer( {:symbol, characters}, rest ) do
    symbol =
      characters
      |> Enum.reverse
      |> to_string
      |> String.to_atom

    [ { :symbol, symbol } | ebnf_tokenizer( {:default}, rest ) ]
  end

  # A?
  #  matches A or nothing; optional A.
  def ebnf_tokenizer( {:default}, [ "?" | rest ] ) do
    [ {:question_mark} | ebnf_tokenizer( {:default}, rest ) ]
  end

  # A | B
  #  matches A or B.
  def ebnf_tokenizer( {:default}, [ "|" | rest ] ) do
    [ {:pipe} | ebnf_tokenizer( {:default}, rest ) ]
  end

  # A - B
  #  matches any string that matches A but does not match B.
  def ebnf_tokenizer( {:default}, [ "-" | rest ] ) do
    [ {:minus} | ebnf_tokenizer( {:default}, rest ) ]
  end

  # A+
  #  matches one or more occurrences of A. Concatenation has higher precedence than alternation; thus A+ | B+ is identical to (A+) | (B+).
  def ebnf_tokenizer( {:default}, [ "+" | rest ] ) do
    [ {:plus} | ebnf_tokenizer( {:default}, rest ) ]
  end

  # A*
  #  matches zero or more occurrences of A. Concatenation has higher precedence than alternation; thus A* | B* is identical to (A*) | (B*).
  def ebnf_tokenizer( {:default}, [ "*" | rest ] ) do
    [ {:star} | ebnf_tokenizer( {:default}, rest ) ]
  end

  # (expression)
  #  expression is treated as a unit and may be combined as described in this list.
  def ebnf_tokenizer( { :default }, [ "(" | rest ] ) do
    [ {:open_paren} | ebnf_tokenizer( { :default }, rest ) ]
  end

  def ebnf_tokenizer( { :default }, [ ")" | rest ] ) do
    [ {:close_paren} | ebnf_tokenizer( { :default }, rest ) ]
  end

  # "string"
  #  matches a literal string matching that given inside the double quotes.
  def ebnf_tokenizer( { :default }, [ "\"" | rest ] ) do
    ebnf_tokenizer( { :double_quote, [""] }, rest )
  end

  def ebnf_tokenizer( { :double_quote, prev_string }, [ "\"" | rest ] ) do
    [ {:double_quote, to_string( Enum.reverse(prev_string) ) }
      | ebnf_tokenizer( { :default }, rest ) ]
  end

  def ebnf_tokenizer( { :double_quote, prev_chars }, [ char | rest ] ) do
    ebnf_tokenizer( { :double_quote, [ char | prev_chars ] }, rest )
  end

  # 'string'
  #  matches a literal string matching that given inside the single quotes.
  def ebnf_tokenizer( { :default }, [ "'" | rest ] ) do
    ebnf_tokenizer( { :single_quote, [] }, rest )
  end

  def ebnf_tokenizer( { :single_quote, prev_string }, [ "'" | rest ] ) do
    [ {:single_quote, to_string( Enum.reverse(prev_string) ) }
      | ebnf_tokenizer( { :default }, rest ) ]
  end

  def ebnf_tokenizer( { :single_quote, prev_chars }, [ char | rest ] ) do
    ebnf_tokenizer( { :single_quote, [ char | prev_chars ] }, rest )
  end

  # #xN
  #  where N is a hexadecimal integer, the expression matches the character whose number (code point) in ISO/IEC 10646 is N. The number of
  #  leading zeros in the #xN form is insignificant.
  def ebnf_tokenizer( prev_mode, [ "#", "x" | rest ] ) when prev_mode in [ { :default }, { :bracket } ] do
    ebnf_tokenizer( { :hex_char, prev_mode, [] }, rest )
  end

  def ebnf_tokenizer( { :hex_char, prev_mode, values }, [ char | rest ] ) when (char >= "0" and char <= "9") or ( char >= "a" and char <= "f" ) or ( char >= "A" and char <= "F" ) do
    ebnf_tokenizer( { :hex_char, prev_mode, [ char | values ] }, rest )
  end

  def ebnf_tokenizer( { :hex_char, prev_mode, hex_values }, rest ) do
    { encoded_value, _} =
      hex_values
      |> Enum.reverse
      |> to_string
      |> Integer.parse( 16 )

    [ { :hex_character, encoded_value } | ebnf_tokenizer( prev_mode, rest ) ]
  end

  # [abc], [#xN#xN#xN]
  #  matches any Char with a value among the characters enumerated. Enumerations and ranges can be mixed in one set of brackets.
  # [a-zA-Z], [#xN-#xN]
  #  matches any Char with a value in the range(s) indicated (inclusive).
  # [^a-z], [^#xN-#xN]
  #  matches any Char with a value outside the range indicated.

  # [^abc], [^#xN#xN#xN]
  #  matches any Char with a value not among the characters given. Enumerations and ranges of forbidden values can be mixed in one set of
  #  brackets.
  def ebnf_tokenizer( { :default }, [ "[", "^" | rest ] ) do
    [ { :open_bracket }, { :negation } | ebnf_tokenizer( { :bracket }, rest ) ]
  end

  def ebnf_tokenizer( { :default }, [ "[" | rest ] ) do
    [ { :open_bracket } | ebnf_tokenizer( { :bracket }, rest ) ]
  end


  def ebnf_tokenizer( { :bracket }, [ "-" | rest ] ) do
    [ { :range } | ebnf_tokenizer( { :bracket }, rest ) ]
  end

  def ebnf_tokenizer( { :bracket }, [ "]" | rest ] ) do
    [ { :close_bracket } | ebnf_tokenizer( { :default }, rest ) ]
  end

  def ebnf_tokenizer( { :bracket }, [ char | rest ] ) do
    [ { :character, char } | ebnf_tokenizer( { :bracket }, rest ) ]
  end

  # comments
  def ebnf_tokenizer( { :default }, [ "/", "*" | rest ] ) do
    ebnf_tokenizer( { :comment, [] }, rest )
  end

  def ebnf_tokenizer( { :comment, previous }, [ "*", "/" | rest ] ) do
    [ { :comment, to_string( Enum.reverse( previous ) ) } | ebnf_tokenizer( {:default}, rest ) ]
  end

  def ebnf_tokenizer( { :comment, previous }, [ char | rest ] ) do
    ebnf_tokenizer( { :comment, [ char | previous ] }, rest )
  end

  def ebnf_tokenizer( _, [] ) do
    []
  end

end
