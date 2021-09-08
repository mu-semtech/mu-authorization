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

  defp benchmark(f, name, times \\ 100, warmup \\ true) do
    if warmup do
      Stream.repeatedly(fn -> {} end)
      |> Enum.take(10)
      |> Enum.each(fn _x -> f.() end)
    end

    times =
      Stream.repeatedly(fn -> {} end)
      |> Enum.take(times)
      |> Enum.map(fn _ ->
        f
        |> :timer.tc()
        |> elem(0)
      end)

    IO.inspect(
      {Tester.Generator.median(times), Tester.Generator.mean(times), Tester.Generator.standard_deviation(times)},
      label: name <> " Took {mid, mean, std} μs"
    )
  end

  def new_parse_query(query, parsers) do
    rule_name = :Sparql
    {parser, _} = Map.get(parsers, rule_name)

    EbnfParser.ParseProtocol.parse(parser, parsers, query |> String.graphemes())
  end

  defp new_parse_query_like_old(query, parsers) do
    [sub | _x] = new_parse_query(query, parsers).match_construct
    %InterpreterTerms.SymbolMatch{symbol: :Sparql, submatches: [sub], string: sub.string}
  end

  defp old_parse_query_with_diff(query) do
    query |> Parser.parse_query_full()
  end

  defp old_parse_query(query) do
    {_matched, out} = query |> Parser.parse_query_first()
    out
  end

  # equivalent to setting @tag key: true
  @tag :bench
  test "parse SPARQL query bench thing" do
    simple_query = "SELECT * WHERE { ?s ?p ?o }"
    parsers = Parser.parsers_sparql()

    bench1 = fn -> old_parse_query(simple_query) end
    bench2 = fn -> old_parse_query_with_diff(simple_query) end

    bench3 = fn -> new_parse_query_like_old(simple_query, parsers) end

    IO.puts("\nparse SPARQL query bench thing")
    benchmark(bench1, "Old Parser", 100, false)
    benchmark(bench2, "Old Parser with diff", 100, false)
    benchmark(bench2, "New Parser", 100, false)

    assert bench1.() === bench2.()
  end

  @tag :bench
  test "parse SPARQL invalid query bench thing" do
    simple_query = "SELECT WHERE { ?s ?p ?o }"
    parsers = Parser.parsers_sparql()

    bench1 = fn -> old_parse_query(simple_query) end
    bench2 = fn -> new_parse_query(simple_query, parsers) end

    IO.puts("\nparse SPARQL invalid query bench thing")
    benchmark(bench1, "Old Parser", 100, false)
    benchmark(bench2, "New Parser", 100, false)

    assert true
  end
end
