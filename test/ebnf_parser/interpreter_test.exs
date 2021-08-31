defmodule InterpreterTest do
  use ExUnit.Case
  alias EbnfParser.Sparql

  @syntax_str %{
    non_terminal: [
      "Expression ::= '(' Expression ')' | Times",
      "Times ::= (POS '*' Expression) | Addition",
      "Addition ::= (POS '+' Expression) | POS"
    ],
    terminal: [
      "POS ::= '-'? [0-9]+"
    ]
  }

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

  test "test Symbols in single forms" do
    %{non_terminal: non_terminal_forms, terminal: terminal_forms} = @syntax_str

    non_terminal_map =
      non_terminal_forms
      |> Enum.map(fn x -> Sparql.split_single_form(x, false) end)
      |> Enum.into(%{})

    full_syntax_map =
      terminal_forms
      |> Enum.map(fn x -> Sparql.split_single_form(x, true) end)
      |> Enum.into(non_terminal_map)

    assert Map.has_key?(non_terminal_map, :Addition)
    assert Map.has_key?(non_terminal_map, :Expression)
    assert Map.has_key?(non_terminal_map, :Times)
    assert Map.has_key?(full_syntax_map, :POS)
    assert not Map.has_key?(non_terminal_map, :POS)
    assert map_size(full_syntax_map) == 4
  end

  test "testing test" do
    %{non_terminal: non_terminal_forms, terminal: terminal_forms} = @syntax_str

    non_terminal_map =
      non_terminal_forms
      |> Enum.map(fn x -> Sparql.split_single_form(x, false) end)
      |> Enum.into(%{})

    full_syntax_map =
      terminal_forms
      |> Enum.map(fn x -> Sparql.split_single_form(x, true) end)
      |> Enum.into(non_terminal_map)

    {_, expr} = full_syntax_map[:Expression]

    assert expr == [
      one_of: [
        paren_group: [
          single_quoted_string: "(",
          symbol: :Expression,
          single_quoted_string: ")"
        ],
        symbol: :Times
      ]
    ]
  end

  test "simple test split_single_form" do
    test_string = "TEST ::= [a-z] - 'b'"
    {name, {is_terminal, some}} = Sparql.split_single_form(test_string)

    assert name == :TEST
    assert is_terminal == false
    assert some == [minus: [
      bracket_selector: [range: [character: "a", character: "z"]],
      single_quoted_string: "b"
    ]]

  end

end
