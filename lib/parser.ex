defmodule Parser do
  @moduledoc """
  Parser for the W3C EBNF syntax.
  """

  @type syntax :: %{ optional( atom ) => any }

  @spec split_single_form(String.t, boolean) :: { atom, { boolean, any } }
  def split_single_form( string, terminal\\false ) do
    split_string = String.split( string , "::=", parts: 2 )
    [name, clause] = Enum.map( split_string , &String.trim/1 )
    { String.to_atom( name ), {terminal, full_parse( clause )} }
  end

  def split_forms( forms ) do
    Enum.map( forms, &split_single_form/1 )
  end

  @spec parse_sparql() :: syntax
  def parse_sparql() do
    %{non_terminal: non_terminal_forms, terminal: terminal_forms} = EbnfParser.Forms.sparql

    my_map =
      non_terminal_forms
      |> Enum.map( fn x -> split_single_form( x, false ) end )
      |> Enum.into( %{} )

    terminal_forms
    |> Enum.map( fn x -> split_single_form( x, true ) end )
    |> Enum.into( my_map )
  end

  def parse_query( string, rule\\:Sparql ) do
    EbnfInterpreter.match_sparql_rule( rule, string )
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

  def make_rule_map( rule_strings ) do
    rule_strings
    |> Enum.map( &split_single_form/1 )
    |> Enum.into( %{} )
  end

  def parse_and_match( rule, str, prev\\[]) do
    rule = Parser.full_parse( rule )
    chars = String.codepoints( str )
    EbnfInterpreter.eagerly_match_rule( chars, %{}, rule, prev )
  end

end
