alias InterpreterTerms.SymbolMatch, as: Sym
alias Updates.QueryAnalyzer.Types.Quad, as: Quad

defmodule Updates.QueryConstructors do
  def make_select_query(variable_syms, group_graph_pattern_sym ) do
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
                        %InterpreterTerms.WordMatch{word: "SELECT"} |
                        variable_syms ]
                    },
                    %Sym{
                      symbol: :WhereClause,
                      submatches: [
                        %InterpreterTerms.WordMatch{word: "WHERE"},
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
  def make_insert_query( quads ) do
    %InterpreterTerms.SymbolMatch{
      symbol: :Sparql,
      submatches: [
        %InterpreterTerms.SymbolMatch{
          symbol: :UpdateUnit,
          submatches: [
            %InterpreterTerms.SymbolMatch{
              symbol: :Update,
              submatches: [
                %InterpreterTerms.SymbolMatch{
                  symbol: :Prologue,
                  submatches: [] },
                %InterpreterTerms.SymbolMatch{
                  symbol: :Update1,
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :InsertData,
                      submatches: [
                        %InterpreterTerms.WordMatch{word: "INSERT DATA"},
                        %InterpreterTerms.SymbolMatch{
                          symbol: :QuadData,
                          submatches: [
                            %InterpreterTerms.WordMatch{word: "{"},
                            %InterpreterTerms.SymbolMatch{
                              symbol: :Quads,
                              submatches: quads },
                            %InterpreterTerms.WordMatch{word: "}"} ] } ] } ] } ] } ] } ] }
  end

  def make_quad_match_from_quad( %Quad{ subject: subject, predicate: predicate, object: object, graph: graph } ) do
    %InterpreterTerms.SymbolMatch{
      symbol: :QuadsNotTriples,
      submatches: [
        %InterpreterTerms.WordMatch{word: "GRAPH"},
        %InterpreterTerms.SymbolMatch{
          symbol: :VarOrIri,
          submatches: [
            Updates.QueryAnalyzer.P.to_solution_sym( graph )
          ]
        },
        %InterpreterTerms.WordMatch{word: "{"},
        %InterpreterTerms.SymbolMatch{
          symbol: :TriplesTemplate,
          submatches: [
            %InterpreterTerms.SymbolMatch{
              symbol: :TriplesSameSubject,
              submatches: [
                %InterpreterTerms.SymbolMatch{
                  symbol: :VarOrTerm,
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :GraphTerm,
                      submatches: [
                        Updates.QueryAnalyzer.P.to_solution_sym( subject ) ] } ] },
                %InterpreterTerms.SymbolMatch{
                  symbol: :PropertyListNotEmpty,
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :Verb,
                      submatches: [
                        %InterpreterTerms.SymbolMatch{
                          symbol: :VarOrIri,
                          submatches: [
                            Updates.QueryAnalyzer.P.to_solution_sym( predicate ) ] } ] },
                    %InterpreterTerms.SymbolMatch{
                      symbol: :ObjectList,
                      submatches: [
                        %InterpreterTerms.SymbolMatch{
                          symbol: :Object,
                          submatches: [
                            %InterpreterTerms.SymbolMatch{
                              symbol: :GraphNode,
                              submatches: [
                                %InterpreterTerms.SymbolMatch{
                                  symbol: :VarOrTerm,
                                  submatches: [
                                    %InterpreterTerms.SymbolMatch{
                                      symbol: :GraphTerm,
                                      submatches: [
                                        Updates.QueryAnalyzer.P.to_solution_sym( object )] } ] } ] } ] } ] } ] } ] } ] },
        %InterpreterTerms.WordMatch{word: "}" }
      ]
    }
  end
end
