defmodule Parsertest do
  use ExUnit.Case
  doctest EbnfParser.Parser

  def tap( string ) do
    EbnfParser.Parser.tokenize_and_parse( string )
  end
end
