defmodule Parser do
  alias Interpreter.Diff.Store, as: DiffStore

  @moduledoc """
  Entrypoint to parse SPARQL queries and the W3C EBNF syntax.
  """
  @type syntax :: %{optional(atom) => any}
  @type unparsed_query :: String.t()
  @type query :: %InterpreterTerms.SymbolMatch{} | %InterpreterTerms.WordMatch{}

  @spec parse_sparql() :: syntax
  def parse_sparql() do
    EbnfParser.Sparql.syntax()
  end

  @spec parse_query(unparsed_query, atom) :: query() | {:fail}
  def parse_query(string, rule \\ :Sparql) do
    EbnfInterpreter.match_sparql_rule(rule, string)
  end

  def parse_query_all(string, rule_name \\ :Sparql) do
    rule = {:symbol, rule_name}
    state = %Generator.State{chars: String.graphemes(string), syntax: Parser.parse_sparql()}

    EbnfParser.GeneratorConstructor.dispatch_generation(rule, state)
    |> EbnfInterpreter.generate_all_options()
  end

  def parse_query_full(query, rule_name \\ :Sparql, syntax \\ Parser.parse_sparql()) do
    case DiffStore.parse(query, rule_name) do
      {:fail} ->
        Interpreter.CachedInterpreter.parse_query_full(query, rule_name, syntax)
        |> DiffStore.maybe_push_solution(0.2)

      result ->
        result
    end
  end

  def parse_query_full_local(query, rule_name, template_local_store) do
    %{sparql_syntax: sparql_syntax} = template_local_store

    case DiffStore.parse_with_local_store(query, rule_name, template_local_store) do
      {:fail} ->
        Logging.EnvLog.log(:log_template_matcher_performance, "Template: no")

        result = Interpreter.CachedInterpreter.parse_query_full(query, rule_name, sparql_syntax)

        new_template_local_store =
          DiffStore.maybe_push_solution_sync(
            result,
            0.2,
            rule_name,
            template_local_store
          )

        {result, new_template_local_store}

      response ->
        Logging.EnvLog.log(:log_template_matcher_performance, "Template: yes")
        response
    end
  end

  @doc """
  Parses the query and yields the first (possibly non-complete) match.
  """
  @spec parse_query_first(String.t(), atom) :: {unparsed_query, query()} | {:fail}
  def parse_query_first(query, rule_name \\ :Sparql, syntax \\ parse_sparql()) do
    rule = {:symbol, rule_name}
    state = %Generator.State{chars: String.graphemes(query), syntax: syntax}

    generator = EbnfParser.GeneratorConstructor.dispatch_generation(rule, state)

    case EbnfParser.Generator.emit(generator) do
      {:ok, _, %Generator.Result{matched_string: matched_string, match_construct: [construct]}} ->
        {matched_string, construct}

      {:fail} ->
        {:fail}
    end
  end

  defp test_full_solution_for_generator(generator) do
    case EbnfParser.Generator.emit(generator) do
      {:ok, new_state, answer} ->
        if Generator.Result.full_match?(answer) do
          true
        else
          test_full_solution_for_generator(new_state)
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
  @spec test_full_solution(unparsed_query, atom) :: true | false
  def test_full_solution(query, rule_name \\ :Sparql) do
    rule = {:symbol, rule_name}
    state = %Generator.State{chars: String.graphemes(query), syntax: Parser.parse_sparql()}

    EbnfParser.GeneratorConstructor.dispatch_generation(rule, state)
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
  def full_parse(string) do
    EbnfParser.Parser.tokenize_and_parse(string)
  end

  defp parser_from_rule({k, {_terminal, v}}) do
    parser = v |> EbnfParser.GeneratorConstructor.to_term() |> EbnfParser.ParserProtocol.make_parser()
    {k, parser}
  end

  def make_parsers(syntax) do
    Map.new(syntax, &parser_from_rule/1)
  end
end
