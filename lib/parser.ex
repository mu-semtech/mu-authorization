defmodule Parser do
  @moduledoc """
  Parser for the W3C EBNF syntax.
  """

  def split_single_form( string ) do
    split_string = String.split( string , "::=", parts: 2 )
    [name, clause] = Enum.map( split_string , &String.trim/1 )
    { String.to_atom( name ), full_parse( clause ) }
  end

  def split_forms( forms ) do
    Enum.map( forms, &split_single_form/1 )
  end

  def parse_sparql() do
    split_forms( EbnfParser.Forms.sparql )
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
    code_string = String.codepoints( string )
    EbnfParser.Tokenizer.ebnf_tokenizer( { :default }, code_string )
    |> EbnfParser.Parser.ebnf_parser
    |> Enum.reverse
    |> ( Enum.map &EbnfParser.Parser.ebnf_parser_reverse_order/1 )
  end



end
