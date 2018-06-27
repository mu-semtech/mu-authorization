defmodule Parser do
  @moduledoc """
  Parser for the W3C EBNF syntax.
  """
  @type syntax :: %{ optional( atom ) => any }

  @spec parse_sparql() :: syntax
  def parse_sparql() do
    EbnfParser.Sparql.syntax
  end

  def parse_query( string, rule\\:Sparql ) do
    EbnfInterpreter.match_sparql_rule( rule, string )
  end

  def parse_query_all( string, rule_name\\:Sparql ) do
    rule = {:symbol, rule_name}
    state = %Generator.State{ chars: String.graphemes( string ), syntax: Parser.parse_sparql }

    EbnfParser.GeneratorConstructor.dispatch_generation( rule, state )
    |> EbnfInterpreter.generate_all_options
  end

  def parse_query_full( query, rule_name\\:Sparql, syntax\\Parser.parse_sparql ) do
    Interpreter.CachedInterpreter.parse_query_full( query, rule_name, syntax )
  end

  @doc """
  Parses the query and yields the first (possibly non-complete) match.
  """
  def parse_query_first( query, rule_name\\:Sparql, syntax\\Parser.parse_sparql) do
    rule = {:symbol, rule_name}
    state = %Generator.State{ chars: String.graphemes( query ), syntax: syntax }

    generator = EbnfParser.GeneratorConstructor.dispatch_generation( rule, state )
    case EbnfParser.Generator.emit( generator ) do
      { :ok, _, %Generator.Result{ matched_string: matched_string, match_construct: [construct] } } ->
        { matched_string, construct }
      { :fail } -> { :fail }
    end
  end

  defp test_full_solution_for_generator( generator ) do
    case EbnfParser.Generator.emit( generator ) do
      {:ok, new_state , answer } ->
        if Generator.Result.full_match? answer do
          true
        else
          test_full_solution_for_generator( new_state )
        end
      {:fail} ->
        false
    end
  end

  @doc """
    Similar to parse_query_full, but handier in a setting where you
    want to test whether a solution would exist or not.  This is not
    cheaper to execute than finding a solution.
  """
  def test_full_solution( query, rule_name\\:Sparql ) do
    rule = {:symbol, rule_name}
    state = %Generator.State{ chars: String.graphemes( query ), syntax: Parser.parse_sparql }

    EbnfParser.GeneratorConstructor.dispatch_generation( rule, state )
    |> test_full_solution_for_generator
  end

  @doc """
  ## Examples
  iex> Parser.full_parse( "FOO" )
  [{ :symbol, :FOO }]

  iex> Parser.full_parse( "FOO BAR" )
  [symbol: :FOO, symbol: :BAR]

  iex> Parser.full_parse( "( FOO BAR )" )
  [paren_group: [ symbol: :FOO, symbol: :BAR]]

  iex> Parser.full_parse( "( FOO BAR )*" )
  [maybe_many: [paren_group: [ symbol: :FOO, symbol: :BAR]]]

  iex> Parser.full_parse( "( FOO BAR* (FOO|BAR) )+" )
  [one_or_more: [ paren_group: [ symbol: :FOO, maybe_many: [ symbol: :BAR ], paren_group: [ one_of: [ symbol: :FOO, symbol: :BAR ] ] ] ]]

  """
  def full_parse( string ) do
    EbnfParser.Parser.tokenize_and_parse( string )
  end

  def parse_and_match( rule, str, prev\\[]) do
    rule = Parser.full_parse( rule )
    chars = String.codepoints( str )
    EbnfInterpreter.eagerly_match_rule( chars, %{}, rule, prev )
  end

end
