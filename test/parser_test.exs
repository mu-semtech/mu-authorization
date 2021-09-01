defmodule ParserTest do
  use ExUnit.Case
  doctest Parser
  alias EbnfParser.Sparql

  # Yes wrong ebnf, doens't matter
  @syntax_str %{
    non_terminal: [
      "Expression ::= Times",
      "Times ::= (Base '*' Expression) | Addition",
      "Addition ::= (Base '+' Expression) | Base",
      "Base ::= ('(' Expression ')') | POS"
    ],
    terminal: [
      "POS ::= ('-'? [0-9]+) | 'NUMBER'"
    ]
  }

  defp syntax() do
    %{non_terminal: non_terminal_forms, terminal: terminal_forms} = @syntax_str

    non_terminal_map =
      non_terminal_forms
      |> Enum.map(fn x -> Sparql.split_single_form(x, false) end)
      |> Enum.into(%{})

    full_syntax_map =
      terminal_forms
      |> Enum.map(fn x -> Sparql.split_single_form(x, true) end)
      |> Enum.into(non_terminal_map)

    full_syntax_map
  end

  test "parse simple math thing" do
    test_str = "2 + 2"

    parsed =
      test_str
      |> Parser.parse_query_full(:Expression, syntax())

    expected = %InterpreterTerms.SymbolMatch{
      symbol: :Expression,
      string: "2 + 2",
      submatches: [
        %InterpreterTerms.SymbolMatch{
          symbol: :Times,
          string: "2 + 2",
          submatches: [
            %InterpreterTerms.SymbolMatch{
              symbol: :Addition,
              string: "2 + 2",
              submatches: [
                %InterpreterTerms.SymbolMatch{
                  symbol: :Base,
                  string: "2",
                  submatches: [
                    %InterpreterTerms.SymbolMatch{symbol: :POS, string: "2", submatches: :none}
                  ]
                },
                %InterpreterTerms.WordMatch{external: %{}, whitespace: " ", word: "+"},
                %InterpreterTerms.SymbolMatch{
                  symbol: :Expression,
                  string: " 2",
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :Times,
                      string: "2",
                      submatches: [
                        %InterpreterTerms.SymbolMatch{
                          symbol: :Addition,
                          string: "2",
                          submatches: [
                            %InterpreterTerms.SymbolMatch{
                              symbol: :Base,
                              string: "2",
                              submatches: [
                                %InterpreterTerms.SymbolMatch{
                                  symbol: :POS,
                                  string: "2",
                                  submatches: :none
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }

    assert TestHelper.match_ignore_whitespace_and_string(expected, parsed)
  end

  test "parse complexer math thing" do
    test_str = "(2 + NUMBER) * 4"

    parsed =
      test_str
      |> Parser.parse_query_full(:Expression, syntax())

    expected = %InterpreterTerms.SymbolMatch{
      symbol: :Expression,
      string: "(2 + NUMBER) * 4",
      submatches: [
        %InterpreterTerms.SymbolMatch{
          symbol: :Times,
          string: "(2 + NUMBER) * 4",
          submatches: [
            %InterpreterTerms.SymbolMatch{
              symbol: :Base,
              string: "(2 + NUMBER)",
              submatches: [
                %InterpreterTerms.WordMatch{
                  external: %{},
                  whitespace: "",
                  word: "("
                },
                %InterpreterTerms.SymbolMatch{
                  symbol: :Expression,
                  string: "2 + NUMBER",
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :Times,
                      string: "2 + NUMBER",
                      submatches: [
                        %InterpreterTerms.SymbolMatch{
                          symbol: :Addition,
                          string: "2 + NUMBER",
                          submatches: [
                            %InterpreterTerms.SymbolMatch{
                              symbol: :Base,
                              string: "2",
                              submatches: [
                                %InterpreterTerms.SymbolMatch{
                                  symbol: :POS,
                                  string: "2",
                                  submatches: :none
                                }
                              ]
                            },
                            %InterpreterTerms.WordMatch{
                              external: %{},
                              whitespace: " ",
                              word: "+"
                            },
                            %InterpreterTerms.SymbolMatch{
                              symbol: :Expression,
                              string: " NUMBER",
                              submatches: [
                                %InterpreterTerms.SymbolMatch{
                                  symbol: :Times,
                                  string: "NUMBER",
                                  submatches: [
                                    %InterpreterTerms.SymbolMatch{
                                      symbol: :Addition,
                                      string: "NUMBER",
                                      submatches: [
                                        %InterpreterTerms.SymbolMatch{
                                          symbol: :Base,
                                          string: "NUMBER",
                                          submatches: [
                                            %InterpreterTerms.SymbolMatch{
                                              symbol: :POS,
                                              string: "NUMBER",
                                              submatches: :none
                                            }
                                          ]
                                        }
                                      ]
                                    }
                                  ]
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    }
                  ]
                },
                %InterpreterTerms.WordMatch{
                  external: %{},
                  whitespace: "",
                  word: ")"
                }
              ]
            },
            %InterpreterTerms.WordMatch{external: %{}, whitespace: " ", word: "*"},
            %InterpreterTerms.SymbolMatch{
              symbol: :Expression,
              string: " 4",
              submatches: [
                %InterpreterTerms.SymbolMatch{
                  symbol: :Times,
                  string: "4",
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :Addition,
                      string: "4",
                      submatches: [
                        %InterpreterTerms.SymbolMatch{
                          symbol: :Base,
                          string: "4",
                          submatches: [
                            %InterpreterTerms.SymbolMatch{
                              symbol: :POS,
                              string: "4",
                              submatches: :none
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }

    assert TestHelper.match_ignore_whitespace_and_string(expected, parsed)
  end
end
