defmodule EbnfParser.Sparql do
  require Logger
  require ALog
  use GenServer

  defmacro __using__(opts) do
    rule_name = opts[:rule_name] || :Sparql
    syntax = EbnfParser.Sparql.sparql_syntax()
    parsers = EbnfParser.Sparql.make_parsers(syntax)

    escaped_parsers = Macro.escape(parsers)

    {symbol_parser, _} = Map.get(parsers, rule_name)
    escaped_parser = Macro.escape(symbol_parser)

    quote do
      def get_parsers(), do: unquote(escaped_parsers)

      defp parse_and_sort(parser, parsers, str) do
        EbnfParser.ParseProtocol.parse(parser, parsers, str |> String.graphemes())
        |> Enum.max_by(&Generator.Result.length/1, &>=/2)
      end

      def parse(str) do
        parser = unquote(escaped_parser)
        parsers = unquote(escaped_parsers)

        case parse_and_sort(parser, parsers, str) do
          %Generator.Result{matched_string: matched_string, match_construct: [sub | _]} ->
            {matched_string,
             %InterpreterTerms.SymbolMatch{
               symbol: unquote(rule_name),
               submatches: [sub],
               string: sub.string
             }}

          xs ->
            {:fail, xs}
        end
      end

      def parse(str, rule_name) do
        parsers = unquote(escaped_parsers)
        parser = parsers[rule_name]

        case parse_and_sort(parser, parsers, str) do
          [%Generator.Result{} = x | _] ->
            # Is this necessary
            [sub | _x] = x.match_construct

            %InterpreterTerms.SymbolMatch{
              symbol: rule_name,
              submatches: [sub],
              string: sub.string
            }

          xs ->
            xs
        end
      end
    end
  end

  @moduledoc """
  Parser which allows you to efficiently fetch the parsed spraql
  syntax.
  """
  @spec split_single_form(String.t(), boolean) :: {atom, {boolean, any}}

  @type syntax :: %{optional(atom) => any}

  ### GenServer API
  @doc """
    GenServer.init/1 callback
  """
  def init(_) do
    syntax = EbnfParser.Sparql.sparql_syntax()
    parsers = EbnfParser.Sparql.make_parsers(syntax)

    {:ok, {syntax, parsers}}
  end

  @doc """
    GenServer.handle_call/3 callback
  """
  def handle_call(:get_syntax, _from, {syntax, parsers}) do
    {:reply, syntax, {syntax, parsers}}
  end

  def handle_call(:get_parsers, _from, {syntax, parsers}) do
    {:reply, parsers, {syntax, parsers}}
  end

  ### Client API / Helper functions
  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def syntax do
    GenServer.call(__MODULE__, :get_syntax)
  end

  def parsers do
    GenServer.call(__MODULE__, :get_parsers)
  end

  def split_single_form(string, terminal \\ false) do
    split_string = String.split(string, "::=", parts: 2)
    [name, clause] = Enum.map(split_string, &String.trim/1)

    parsed_clause = EbnfParser.Parser.tokenize_and_parse(clause)
    {String.to_atom(name), {terminal, parsed_clause}}
  end

  defp sparql_syntax_ebnf() do
    %{non_terminal: non_terminal_forms, terminal: terminal_forms} = EbnfParser.Forms.sparql()

    non_terminals =
      non_terminal_forms
      |> Enum.map(fn x -> split_single_form(x, false) end)

    terminals =
      terminal_forms
      |> Enum.map(fn x -> split_single_form(x, true) end)

    {non_terminals, terminals}
  end

  @spec sparql_syntax() :: syntax
  def sparql_syntax() do
    {non_terminals, terminals} = sparql_syntax_ebnf()

    full_syntax_map =
      Enum.concat(non_terminals, terminals)
      |> Map.new()

    _regexp_empowered_map =
      full_syntax_map
      |> augment_with_regexp_terminators
  end

  defp parser_from_rule({k, {terminal, v}}) do
    parser =
      v |> EbnfParser.GeneratorConstructor.to_term() |> EbnfParser.ParserProtocol.make_parser()

    {k, {parser, terminal}}
  end

  def make_parsers(syntax) do
    Map.new(syntax, &parser_from_rule/1)
  end

  def augment_with_regexp_terminators(map) do
    map
    # TODO add other string literals
    |> Map.put(
      :STRING_LITERAL_LONG1,
      {true, [regex: ~r/^'''(''|')?([^\\']|(\\[tbnrf'"\\]))*'''/mf]}
    )
    |> Map.put(
      :STRING_LITERAL_LONG2,
      {true, [regex: ~r/^"""(""|")?([^\\"]|(\\[tbnrf"'\\]))*"""/mf]}
    )
    |> Map.put(
      :STRING_LITERAL1,
      {true, [regex: ~r/^'([^\x{27}\x{5C}\x{A}\x{D}]|(\\[tbnrf\\"']))*'/]}
    )
    |> Map.put(
      :STRING_LITERAL2,
      {true, [regex: ~r/^"([^\x{22}\x{5C}\x{A}\x{D}]|(\\[tbnrf\\"']))*"/]}
    )
    |> Map.put(
      :VARNAME,
      {true,
       [
         regex:
           ~r/^[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}_0-9][A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}_0-9\x{00B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]*/u
       ]}
    )
    |> Map.put(
      :PN_PREFIX,
      {true,
       [
         regex:
           ~r/^[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]([A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}_\-0-9\x{00B7}\x{0300}-\x{036F}\x{203F}-\x{2040}\.]*[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}_\-0-9\x{00B7}\x{0300}-\x{036F}\x{203F}-\x{2040}])?/u
       ]}
    )
    |> Map.put(
      :PN_LOCAL,
      {true,
       [
         regex:
           ~r/^([A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}_:0-9]|(%[0-9A-Fa-f][0-9A-Fa-f])|(\\[_~\.\-!$&'()*+,;=\/?#@%]))(([A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}_\-0-9\x{00B7}\x{0300}-\x{036F}\x{203F}-\x{2040}\.:]|(%[0-9A-Fa-f][0-9A-Fa-f])|(\\[_~\.\-!$&'()*+,;=\/?#@%]))*(([A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}_\-0-9\x{00B7}\x{0300}-\x{036F}\x{203F}-\x{2040}:])|(%[0-9a-zA-Z][0-9a-zA-Z])|(\\[_~\.\-!$&'()*+,;=\/?\#@%])))?/u
       ]}
    )
    |> Map.put(:IRIREF, {true, [regex: ~r/^<([^<>\\"{}|^`\x{00}-\x{20}])*>/u]})
  end

  def sparql_syntax_as_ordered_array do
    %{non_terminal: non_terminal_forms, terminal: terminal_forms} = EbnfParser.Forms.sparql()

    parsed_non_terminal_forms =
      non_terminal_forms
      |> Enum.map(fn x -> {x, split_single_form(x, false)} end)

    parsed_terminal_forms =
      terminal_forms
      |> Enum.map(fn x -> {x, split_single_form(x, true)} end)

    parsed_non_terminal_forms ++ parsed_terminal_forms
  end
end
