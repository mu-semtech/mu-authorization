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

    assert TestHelper.match_ignore_whitespace_and_string(
             parsed_simple_query,
             standard_simple_query
           )
  end

  test "parse a wrong SPARQL query" do
    simple_query = "SELECT * WHERE "
    res = simple_query |> Parser.parse_query_full()
    assert is_nil(res)
  end

  defp benchmark(f, name, times \\ 50, warmup \\ true) do
    if warmup do
      Stream.repeatedly(fn -> {} end)
      |> Enum.take(10)
      |> Enum.each(fn _x -> f.() end)
    end

    times =
      Stream.repeatedly(fn -> {} end)
      |> Enum.take(times)
      |> Enum.map(fn _ ->
        start_time = :os.system_time(:microsecond)
        _returned = f.()
        end_time = :os.system_time(:microsecond)
        end_time - start_time
      end)

    IO.inspect(
      {TestHelper.median(times), TestHelper.mean(times), TestHelper.standard_deviation(times)},
      label: name <> "Took {mid, mean, std} μs"
    )
  end

  defp parse_query(query, true) do
    rule_name = :Sparql
    parsers = Parser.parsers_sparql()
    parser = Map.get(parsers, rule_name)

    EbnfParser.ParseProtocol.parse(parser, parsers, query |> String.graphemes())
    |> Enum.take(1)
  end

  defp parse_query(query, false) do
    query |> Parser.parse_query_full()
  end

  # equivalent to setting @tag key: true
  @tag :bench
  test "parse SPARQL query bench thing" do
    simple_query = "SELECT * WHERE { ?s ?p ?o }"

    bench1 = fn -> parse_query(simple_query, false) end
    bench2 = fn -> parse_query(simple_query, true) end

    benchmark(bench1, "Old Parser")
    benchmark(bench2, "New Parser")

    assert true
  end
end
