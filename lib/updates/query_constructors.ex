defmodule Updates.QueryConstructors do
  alias Updates.QueryAnalyzer.P, as: QueryAnalyzerProtocol
  alias InterpreterTerms.SymbolMatch, as: Sym
  alias InterpreterTerms.WordMatch, as: Word
  alias Updates.QueryAnalyzer.Types.Quad, as: Quad

  defp leaf_to_data_block_value(leaf) do
    %Sym{
      symbol: :DataBlockValue,
      submatches: [
        QueryAnalyzerProtocol.to_solution_sym(leaf)
      ]
    }
  end

  defp map_quad_to_bracet_data_block_values(%Quad{
         subject: subject,
         predicate: predicate,
         object: object,
         graph: graph
       }) do
    [
      %Word{word: "("},
      leaf_to_data_block_value(graph),
      leaf_to_data_block_value(subject),
      leaf_to_data_block_value(predicate),
      leaf_to_data_block_value(object),
      %Word{word: ")"}
    ]
  end

  @doc """
  Creates a valid CONSTRUCT query, determining the existence of ~~life~~ quads
  Can be used as multiple ASK queries with only a little bit of suffering
  """
  def make_asks_query(quads) do
    graph = make_var_symbol("?g")
    subject = make_var_symbol("?s")
    predicate = make_var_symbol("?p")
    object = make_var_symbol("?o")

    where_clause = make_quad_match_values(graph, subject, predicate, object, quads)

    %Sym{
      symbol: :Sparql,
      submatches: [
        %Sym{
          symbol: :QueryUnit,
          submatches: [
            %Sym{
              symbol: :Query,
              submatches: [
                %Sym{
                  symbol: :Prologue,
                  submatches: []
                },
                %Sym{
                  symbol: :ConstructQuery,
                  submatches: [
                    %Word{word: "CONSTRUCT"},
                    %Sym{
                      symbol: :ConstructTemplate,
                      submatches: [
                        %Word{word: "{"},
                        %Sym{
                          symbol: :ConstructTriples,
                          submatches: [
                            make_simple_triples_same_subject(
                              subject,
                              predicate,
                              object
                            )
                          ]
                        },
                        %Word{word: "}"}
                      ]
                    },
                    %Sym{
                      symbol: :WhereClause,
                      submatches: [
                        %Word{word: "WHERE"},
                        where_clause
                      ]
                    },
                    %Sym{
                      symbol: :SolutionModifier,
                      submatches: []
                    }
                  ]
                },
                %Sym{
                  symbol: :ValuesClause,
                  submatches: []
                }
              ]
            }
          ]
        }
      ]
    }
  end

  def make_quad_match_values(graph, subject, predicate, object, quads) do
    matches = quads |> Enum.flat_map(&map_quad_to_bracet_data_block_values/1)

    %Sym{
      symbol: :GroupGraphPattern,
      submatches: [
        %Word{word: "{"},
        %Sym{
          symbol: :GroupGraphPatternSub,
          submatches: [
            %Sym{
              symbol: :GraphPatternNotTriples,
              submatches: [
                %Sym{
                  symbol: :InlineData,
                  submatches: [
                    %Word{word: "VALUES"},
                    %Sym{
                      symbol: :DataBlock,
                      submatches: [
                        %Sym{
                          symbol: :InlineDataFull,
                          submatches:
                            [
                              %Word{word: "("},
                              graph,
                              subject,
                              predicate,
                              object,
                              %Word{word: ")"},
                              %Word{word: "{"}
                            ] ++
                              matches ++
                              [
                                %Word{word: "}"}
                              ]
                        }
                      ]
                    }
                  ]
                }
              ]
            },
            %Sym{
              symbol: :GraphPatternNotTriples,
              submatches: [
                %Sym{
                  symbol: :GraphGraphPattern,
                  submatches: [
                    %Word{word: "GRAPH"},
                    %Sym{
                      symbol: :VarOrIri,
                      submatches: [
                        graph
                      ]
                    },
                    %Sym{
                      symbol: :GroupGraphPattern,
                      submatches: [
                        %Word{word: "{"},
                        %Sym{
                          symbol: :GroupGraphPatternSub,
                          submatches: [
                            %Sym{
                              symbol: :TriplesBlock,
                              submatches: [
                                make_simple_triples_same_subject_path(
                                  subject,
                                  predicate,
                                  object
                                ),
                                %Word{word: "."}
                              ]
                            }
                          ]
                        },
                        %Word{word: "}"}
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        },
        %Word{word: "}"}
      ]
    }
  end

  @doc """
  Creates a valid ASK query, for a single quad
  """
  def make_ask_query(quad) do
    quad_pattern = %Sym{
      symbol: :QuadData,
      submatches: [
        %Word{external: %{}, whitespace: "", word: "{"},
        %Sym{
          symbol: :Quads,
          submatches: [
            make_quad_match_from_quad(quad)
          ]
        },
        %Word{external: %{}, whitespace: "", word: "}"}
      ]
    }

    group_graph_pattern = Manipulator.Transform.quad_data_to_group_graph_pattern(quad_pattern)

    %Sym{
      symbol: :Sparql,
      submatches: [
        %Sym{
          symbol: :QueryUnit,
          submatches: [
            %Sym{
              symbol: :Query,
              submatches: [
                %Sym{
                  symbol: :Prologue,
                  submatches: []
                },
                %Sym{
                  symbol: :AskQuery,
                  submatches: [
                    %Word{word: "ASK"},
                    %Sym{
                      symbol: :WhereClause,
                      submatches: [
                        %Word{word: "WHERE"},
                        group_graph_pattern
                      ]
                    },
                    %Sym{
                      symbol: :SolutionModifier,
                      submatches: []
                    }
                  ]
                },
                %Sym{
                  symbol: :ValuesClause,
                  submatches: []
                }
              ]
            }
          ]
        }
      ]
    }
  end

  def make_select_query(variable_syms, group_graph_pattern_sym) do
    %Sym{
      symbol: :Sparql,
      submatches: [
        %Sym{
          symbol: :QueryUnit,
          submatches: [
            %Sym{
              symbol: :Query,
              submatches: [
                %Sym{
                  symbol: :Prologue,
                  submatches: []
                },
                %Sym{
                  symbol: :SelectQuery,
                  submatches: [
                    %Sym{
                      symbol: :SelectClause,
                      submatches: [
                        %Word{word: "SELECT"}
                        | variable_syms
                      ]
                    },
                    %Sym{
                      symbol: :WhereClause,
                      submatches: [
                        %Word{word: "WHERE"},
                        group_graph_pattern_sym
                      ]
                    },
                    %Sym{
                      symbol: :SolutionModifier,
                      submatches: []
                    }
                  ]
                },
                %Sym{
                  symbol: :ValuesClause,
                  submatches: []
                }
              ]
            }
          ]
        }
      ]
    }
  end

  def make_select_distinct_query(variable_syms, group_graph_pattern_sym) do
    %Sym{
      symbol: :Sparql,
      submatches: [
        %Sym{
          symbol: :QueryUnit,
          submatches: [
            %Sym{
              symbol: :Query,
              submatches: [
                %Sym{
                  symbol: :Prologue,
                  submatches: []
                },
                %Sym{
                  symbol: :SelectQuery,
                  submatches: [
                    %Sym{
                      symbol: :SelectClause,
                      submatches: [
                        %Word{word: "SELECT"},
                        %Word{word: "DISTINCT"}
                        | variable_syms
                      ]
                    },
                    %Sym{
                      symbol: :WhereClause,
                      submatches: [
                        %Word{word: "WHERE"},
                        group_graph_pattern_sym
                      ]
                    },
                    %Sym{
                      symbol: :SolutionModifier,
                      submatches: []
                    }
                  ]
                },
                %Sym{
                  symbol: :ValuesClause,
                  submatches: []
                }
              ]
            }
          ]
        }
      ]
    }
  end

  @doc """
  Creates a valid insert data query, assuming quads is an array of
  solutions container :QuadsNotTriples.
  """
  def make_insert_query(quads) do
    %Sym{
      symbol: :Sparql,
      submatches: [
        %Sym{
          symbol: :UpdateUnit,
          submatches: [
            %Sym{
              symbol: :Update,
              submatches: [
                %Sym{symbol: :Prologue, submatches: []},
                %Sym{
                  symbol: :Update1,
                  submatches: [
                    %Sym{
                      symbol: :InsertData,
                      submatches: [
                        %Word{word: "INSERT"},
                        %Word{word: "DATA"},
                        %Sym{
                          symbol: :QuadData,
                          submatches: [
                            %Word{word: "{"},
                            %Sym{symbol: :Quads, submatches: quads},
                            %Word{word: "}"}
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
  end

  def make_delete_query(quads) do
    %Sym{
      symbol: :Sparql,
      submatches: [
        %Sym{
          symbol: :UpdateUnit,
          submatches: [
            %Sym{
              symbol: :Update,
              submatches: [
                %Sym{symbol: :Prologue, submatches: []},
                %Sym{
                  symbol: :Update1,
                  submatches: [
                    %Sym{
                      symbol: :DeleteData,
                      submatches: [
                        %Word{word: "DELETE"},
                        %Word{word: "DATA"},
                        %Sym{
                          symbol: :QuadData,
                          submatches: [
                            %Word{word: "{"},
                            %Sym{symbol: :Quads, submatches: quads},
                            %Word{word: "}"}
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
  end

  def make_quad_match_from_quad(%Quad{
        subject: subject,
        predicate: predicate,
        object: object,
        graph: graph
      }) do
    %Sym{
      symbol: :QuadsNotTriples,
      submatches: [
        %Word{word: "GRAPH"},
        %Sym{
          symbol: :VarOrIri,
          submatches: [
            QueryAnalyzerProtocol.to_solution_sym(graph)
          ]
        },
        %Word{word: "{"},
        %Sym{
          symbol: :TriplesTemplate,
          submatches: [
            %Sym{
              symbol: :TriplesSameSubject,
              submatches: [
                %Sym{
                  symbol: :VarOrTerm,
                  submatches: [
                    %Sym{
                      symbol: :GraphTerm,
                      submatches: [QueryAnalyzerProtocol.to_solution_sym(subject)]
                    }
                  ]
                },
                %Sym{
                  symbol: :PropertyListNotEmpty,
                  submatches: [
                    %Sym{
                      symbol: :Verb,
                      submatches: [
                        %Sym{
                          symbol: :VarOrIri,
                          submatches: [QueryAnalyzerProtocol.to_solution_sym(predicate)]
                        }
                      ]
                    },
                    %Sym{
                      symbol: :ObjectList,
                      submatches: [
                        %Sym{
                          symbol: :Object,
                          submatches: [
                            %Sym{
                              symbol: :GraphNode,
                              submatches: [
                                %Sym{
                                  symbol: :VarOrTerm,
                                  submatches: [
                                    %Sym{
                                      symbol: :GraphTerm,
                                      submatches: [
                                        QueryAnalyzerProtocol.to_solution_sym(object)
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
        %Word{word: "}"}
      ]
    }
  end

  @doc """
  Constructs a query which selects triples from the specified graph.
  The triples are stored as ?s ?p and ?o variables.
  """
  @spec make_select_triples_from_graph_query(%Sym{}) :: Parser.query()
  def make_select_triples_from_graph_query(graph_iri) do
    variables = [
      make_var_symbol("?s"),
      make_var_symbol("?p"),
      make_var_symbol("?o")
    ]

    group_graph_pattern_sym = %Sym{
      symbol: :GroupGraphPattern,
      submatches: [
        %Word{external: %{}, whitespace: "", word: "{"},
        %Sym{
          symbol: :GroupGraphPatternSub,
          submatches: [
            %Sym{
              symbol: :GraphPatternNotTriples,
              submatches: [
                %Sym{
                  symbol: :GraphGraphPattern,
                  submatches: [
                    %Word{external: %{}, whitespace: "", word: "GRAPH"},
                    %Sym{symbol: :VarOrIri, submatches: [graph_iri]},
                    %Sym{
                      symbol: :GroupGraphPattern,
                      submatches: [
                        %Word{external: %{}, whitespace: "", word: "{"},
                        %Sym{
                          symbol: :GroupGraphPatternSub,
                          submatches: [
                            %Sym{
                              symbol: :TriplesBlock,
                              submatches: [
                                make_simple_triples_same_subject_path(
                                  make_var_symbol("?s"),
                                  make_var_symbol("?p"),
                                  make_var_symbol("?o")
                                ),
                                %Word{external: %{}, whitespace: "", word: "."}
                              ]
                            }
                          ]
                        },
                        %Word{external: %{}, whitespace: " ", word: "}"}
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        },
        %Word{external: %{}, whitespace: " ", word: "}"}
      ]
    }

    make_select_distinct_query(variables, group_graph_pattern_sym)
  end

  def make_var_symbol(str) do
    %Sym{
      symbol: :Var,
      submatches: [%Sym{symbol: :VAR1, string: str, submatches: :none}]
    }
  end

  defp make_simple_triples_same_subject_path(
         subject_var_or_term,
         predicate_var_or_term,
         object_var_or_term
       ) do
    %Sym{
      symbol: :TriplesSameSubjectPath,
      submatches: [
        %Sym{symbol: :VarOrTerm, submatches: [subject_var_or_term]},
        %Sym{
          symbol: :PropertyListPathNotEmpty,
          submatches: [
            %Sym{
              symbol: :VerbSimple,
              submatches: [predicate_var_or_term]
            },
            %Sym{
              symbol: :ObjectListPath,
              submatches: [
                %Sym{
                  symbol: :ObjectPath,
                  submatches: [
                    %Sym{
                      symbol: :GraphNodePath,
                      submatches: [
                        %Sym{
                          symbol: :VarOrTerm,
                          submatches: [object_var_or_term]
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
  end

  defp make_simple_triples_same_subject(
         subject_var_or_term,
         predicate_var_or_term,
         object_var_or_term
       ) do
    %Sym{
      symbol: :TriplesSameSubject,
      submatches: [
        %Sym{symbol: :VarOrTerm, submatches: [subject_var_or_term]},
        %Sym{
          symbol: :PropertyListNotEmpty,
          submatches: [
            %Sym{
              symbol: :Verb,
              submatches: [
                %Sym{
                  symbol: :VarOrIri,
                  submatches: [
                    predicate_var_or_term
                  ]
                }
              ]
            },
            %Sym{
              symbol: :ObjectList,
              submatches: [
                %Sym{
                  symbol: :Object,
                  submatches: [
                    %Sym{
                      symbol: :GraphNode,
                      submatches: [
                        %Sym{
                          symbol: :VarOrTerm,
                          submatches: [object_var_or_term]
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
  end
end
