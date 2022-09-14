defmodule InterpreterTest do
  use ExUnit.Case
  doctest EbnfInterpreter

  def t_ep(str) do
    EbnfInterpreter.t_ep(str)
  end

  def parse_and_match(rule, str, options \\ %{}) do
    case EbnfInterpreter.first_match(rule, str, options) do
      {left_chars, matched, match_info} ->
        {:ok, left_chars, matched, match_info}

      stuff ->
        stuff
    end
  end
end
