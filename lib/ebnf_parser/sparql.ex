defmodule EbnfParser.Sparql do
  require Logger
  require ALog
  use GenServer

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
    {:ok, EbnfParser.Sparql.parse_sparql()}
  end

  @doc """
    GenServer.handle_call/3 callback
  """
  def handle_call(:get, _from, syntax) do
    {:reply, syntax, syntax}
  end

  ### Client API / Helper functions
  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def syntax do
    GenServer.call(__MODULE__, :get)
  end

  def split_single_form(string, terminal \\ false) do
    split_string = String.split(string, "::=", parts: 2)
    [name, clause] = Enum.map(split_string, &String.trim/1)
    {String.to_atom(name), {terminal, full_parse(clause)}}
  end

  def full_parse(string) do
    EbnfParser.Parser.tokenize_and_parse(string)
  end

  def split_forms(forms) do
    Enum.map(forms, &split_single_form/1)
  end

  @spec parse_sparql() :: syntax
  def parse_sparql() do
    %{non_terminal: non_terminal_forms, terminal: terminal_forms} = EbnfParser.Forms.sparql()

    non_terminal_map =
      non_terminal_forms
      |> Enum.map(fn x -> split_single_form(x, false) end)
      |> Enum.into(%{})

    full_syntax_map =
      terminal_forms
      |> Enum.map(fn x -> split_single_form(x, true) end)
      |> Enum.into(non_terminal_map)

    _regexp_empowered_map =
      full_syntax_map
      |> augment_with_regexp_terminators
  end

  def augment_with_regexp_terminators(map) do
    map
    # TODO add other string literals
    |> Map.put(
      :STRING_LITERAL_LONG2,
      {true, [regex: ~r/^"""(""|")?([^\\"]|(\\[tbnrf"'\\]))*"""/m]}
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

  def parse_sparql_as_ordered_array do
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
