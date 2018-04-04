defmodule InterpreterTest do
  use ExUnit.Case
  doctest EbnfInterpreter

  def t_ep( str ) do
    EbnfInterpreter.t_ep( str )
  end

  def parse_and_match( rule, str, prev\\[]) do
    rule = Parser.full_parse( rule )
    chars = String.codepoints( str )
    EbnfInterpreter.eagerly_match_rule( chars, %{}, rule, prev )
  end

end
