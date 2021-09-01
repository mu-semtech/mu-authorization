defmodule SparqlTest do
  use ExUnit.Case
  alias EbnfParser.Sparql
  doctest Sparql

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

    assert TestHelper.match_ignore_whitespace_and_string(parsed_simple_query, standard_simple_query)
  end

  test "parse a wrong SPARQL query" do
    simple_query = "SELECT * WHERE "
    res = simple_query |> Parser.parse_query_full()
    assert is_nil(res)
  end
end
