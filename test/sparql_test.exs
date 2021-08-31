defmodule SparqlTest do
  use ExUnit.Case
  alias EbnfParser.Sparql

  alias InterpreterTerms.SymbolMatch, as: Sym
  alias InterpreterTerms.WordMatch, as: Word
  doctest Sparql

  defp match_ignore_whitespace_and_string(%Sym{symbol: s1, submatches: m1}, %Sym{
         symbol: s2,
         submatches: m2
       })
       when is_list(m1) and is_list(m2) do
    if s1 !== s2 do
      false
    else
      if length(m1) !== length(m2) do
        false
      else
        Enum.zip(m1, m2) |> Enum.all?(fn {x, y} -> match_ignore_whitespace_and_string(x, y) end)
      end
    end
  end

  defp match_ignore_whitespace_and_string(%Sym{symbol: s1, submatches: m1}, %Sym{
         symbol: s2,
         submatches: m2
       }) do
    s1 == s2 and m1 == m2
  end

  defp match_ignore_whitespace_and_string(%Word{word: w1}, %Word{word: w2}) do
    w1 |> String.downcase() == w2 |> String.downcase()
  end

  defp match_ignore_whitespace_and_string(_x, _y) do
    false
  end

  test "parse the simplest SPARQL query" do
    simple_query = "SELECT * WHERE { ?s ?p ?o }"

    standard_simple_query = %InterpreterTerms.SymbolMatch{
      symbol: :Sparql,
      string: "SELECT * WHERE { ?s ?p ?o }",
      submatches: [
        %InterpreterTerms.SymbolMatch{
          symbol: :QueryUnit,
          string: "SELECT * WHERE { ?s ?p ?o }",
          submatches: [
            %InterpreterTerms.SymbolMatch{
              symbol: :Query,
              string: "SELECT * WHERE { ?s ?p ?o }",
              submatches: [
                %InterpreterTerms.SymbolMatch{
                  symbol: :Prologue,
                  string: "",
                  submatches: []
                },
                %InterpreterTerms.SymbolMatch{
                  symbol: :SelectQuery,
                  string: "SELECT * WHERE { ?s ?p ?o }",
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :SelectClause,
                      string: "SELECT *",
                      submatches: [
                        %InterpreterTerms.WordMatch{
                          external: %{},
                          whitespace: "",
                          word: "SELECT"
                        },
                        %InterpreterTerms.WordMatch{
                          external: %{},
                          whitespace: " ",
                          word: "*"
                        }
                      ]
                    },
                    %InterpreterTerms.SymbolMatch{
                      symbol: :WhereClause,
                      string: " WHERE { ?s ?p ?o }",
                      submatches: [
                        %InterpreterTerms.WordMatch{
                          external: %{},
                          whitespace: "",
                          word: "WHERE"
                        },
                        %InterpreterTerms.SymbolMatch{
                          symbol: :GroupGraphPattern,
                          string: " { ?s ?p ?o }",
                          submatches: [
                            %InterpreterTerms.WordMatch{
                              external: %{},
                              whitespace: "",
                              word: "{"
                            },
                            %InterpreterTerms.SymbolMatch{
                              symbol: :GroupGraphPatternSub,
                              string: " ?s ?p ?o",
                              submatches: [
                                %InterpreterTerms.SymbolMatch{
                                  symbol: :TriplesBlock,
                                  string: "?s ?p ?o",
                                  submatches: [
                                    %InterpreterTerms.SymbolMatch{
                                      symbol: :TriplesSameSubjectPath,
                                      string: "?s ?p ?o",
                                      submatches: [
                                        %InterpreterTerms.SymbolMatch{
                                          symbol: :VarOrTerm,
                                          string: "?s",
                                          submatches: [
                                            %InterpreterTerms.SymbolMatch{
                                              symbol: :Var,
                                              string: "?s",
                                              submatches: [
                                                %InterpreterTerms.SymbolMatch{
                                                  symbol: :VAR1,
                                                  string: "?s",
                                                  submatches: :none
                                                }
                                              ]
                                            }
                                          ]
                                        },
                                        %InterpreterTerms.SymbolMatch{
                                          symbol: :PropertyListPathNotEmpty,
                                          string: " ?p ?o",
                                          submatches: [
                                            %InterpreterTerms.SymbolMatch{
                                              symbol: :VerbSimple,
                                              string: "?p",
                                              submatches: [
                                                %InterpreterTerms.SymbolMatch{
                                                  symbol: :Var,
                                                  string: "?p",
                                                  submatches: [
                                                    %InterpreterTerms.SymbolMatch{
                                                      symbol: :VAR1,
                                                      string: "?p",
                                                      submatches: :none
                                                    }
                                                  ]
                                                }
                                              ]
                                            },
                                            %InterpreterTerms.SymbolMatch{
                                              symbol: :ObjectListPath,
                                              string: " ?o",
                                              submatches: [
                                                %InterpreterTerms.SymbolMatch{
                                                  symbol: :ObjectPath,
                                                  string: "?o",
                                                  submatches: [
                                                    %InterpreterTerms.SymbolMatch{
                                                      symbol: :GraphNodePath,
                                                      string: "?o",
                                                      submatches: [
                                                        %InterpreterTerms.SymbolMatch{
                                                          symbol: :VarOrTerm,
                                                          string: "?o",
                                                          submatches: [
                                                            %InterpreterTerms.SymbolMatch{
                                                              symbol: :Var,
                                                              string: "?o",
                                                              submatches: [
                                                                %InterpreterTerms.SymbolMatch{
                                                                  symbol: :VAR1,
                                                                  string: "?o",
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
                                  ]
                                }
                              ]
                            },
                            %InterpreterTerms.WordMatch{
                              external: %{},
                              whitespace: " ",
                              word: "}"
                            }
                          ]
                        }
                      ]
                    },
                    %InterpreterTerms.SymbolMatch{
                      symbol: :SolutionModifier,
                      string: "",
                      submatches: []
                    }
                  ]
                },
                %InterpreterTerms.SymbolMatch{
                  symbol: :ValuesClause,
                  string: "",
                  submatches: []
                }
              ]
            }
          ]
        }
      ]
    }

    parsed_simple_query = simple_query |> Parser.parse_query_full()

    assert match_ignore_whitespace_and_string(parsed_simple_query, standard_simple_query)
  end

  test "parse a wrong SPARQL query" do
    simple_query = "SELECT * WHERE "
    res = simple_query |> Parser.parse_query_full()
    assert is_nil(res)
  end
end
