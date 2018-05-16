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

  @doc """
  Adds a prefix to the query.

  It is assumed the prefix is just the prefix without a colon (:)
  eg: foaf

  It is assumed the printable_iri contains all the escaping for it to
  be added to the graph.  For instance, it would be named
  <http://mu.semte.ch/vocabularies/ext>.
  """
  def add_prefix( element, { prefix, printable_iri } ) do
    # create the new prefix symbol
    prefix_symbolmatch =
      %InterpreterTerms.SymbolMatch{
        symbol: :PrefixDecl,
        submatches: [
          %InterpreterTerms.WordMatch{word: "PREFIX"},
          %InterpreterTerms.SymbolMatch{
            symbol: :PNAME_NS,
            string: prefix <> ":",
            submatches: :none
          },
          %InterpreterTerms.SymbolMatch{
            symbol: :IRIREF,
            string: printable_iri,
            submatches: :none
          }
        ] }

    # add the match to our prologue
    Manipulators.Basics.map_matches( element, fn (element) ->
      case element do
        %InterpreterTerms.SymbolMatch{ symbol: :Prologue, submatches: matches } = match ->
          { :replace_by,
            %{ match |
               string: nil,
               submatches: [ prefix_symbolmatch | matches ] } }
        _ -> { :continue }
      end
    end )
  end
end
