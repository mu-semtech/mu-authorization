defmodule Manipulators.SparqlQuery do

  def add_graph( element, graph \\ "http://mu.semte.ch/application" ) do
    Manipulators.Basics.map_matches( element, fn (element) ->
      case element do
        # TODO: we should possibly do this for every select query
        %InterpreterTerms.SymbolMatch{ symbol: :GroupGraphPattern } ->
          { :replace_by,
            %InterpreterTerms.SymbolMatch{
              symbol: :GroupGraphPattern,
              submatches: [
                %InterpreterTerms.WordMatch{word: "{"},
                %InterpreterTerms.SymbolMatch{
                  symbol: :GroupGraphPatternSub,
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :GraphPatternNotTriples,
                      submatches: [
                        %InterpreterTerms.SymbolMatch{
                          symbol: :GraphGraphPattern,
                          submatches: [
                            %InterpreterTerms.WordMatch{word: "GRAPH"},
                            %InterpreterTerms.SymbolMatch{
                              symbol: :VarOrIri,
                              submatches: [
                                %InterpreterTerms.SymbolMatch{
                                  symbol: :iri,
                                  submatches: [
                                    %InterpreterTerms.SymbolMatch{
                                      string: "<" <> graph <> ">",
                                      submatches: :none,
                                      symbol: :IRIREF } ] } ] },
                            element # replacement
                          ] } ] } ] },
                %InterpreterTerms.WordMatch{word: "}"} ] }
          }
        _ -> { :continue }
      end
    end )
  end

  def add_from_graph( element, graph \\ "http://mu.semte.ch/application" ) do
    Manipulators.Basics.map_matches( element, fn (element ) ->
      case element do
        # TODO: We should verify SelectQuery -> SelectClause
        %InterpreterTerms.SymbolMatch{ symbol: :SelectClause } ->
          { :insert_after,
            %InterpreterTerms.SymbolMatch{
              symbol: :DatasetClause,
              submatches: [
                %InterpreterTerms.WordMatch{word: "FROM"},
                %InterpreterTerms.SymbolMatch{
                  symbol: :DefaultGraphClause,
                  submatches: [
                    %InterpreterTerms.SymbolMatch{
                      symbol: :SourceSelector,
                      submatches: [
                        %InterpreterTerms.SymbolMatch{
                          symbol: :iri,
                          submatches: [
                            %InterpreterTerms.SymbolMatch{
                              symbol: :IRIREF,
                              string: "<" <> graph <> ">",
                              submatches: :none } ] } ] } ] } ] } }
        _ -> { :continue }
      end
    end )
  end

end
