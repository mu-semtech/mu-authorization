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


  @doc """
  Removes the GRAPH statements from a sparql query.
  """
  def remove_graph_statements( element ) do
    # We are interested in converting the GraphGraphPattern into
    # something that does not scope to the graph.
    #
    # At the same level of the GraphGraphPattern, there is the
    # GroupOrUnionGraphPattern.  Both of these use a GroupGraphPattern
    # to identify their matching contents.  Hence, we can translate
    # the GraphGraphPattern into a GroupOrUnionGraphPattern.
    Manipulators.Basics.map_matches( element, fn (child) ->
      case child do
        %InterpreterTerms.SymbolMatch{ symbol: :GraphGraphPattern, submatches: [_,_,group_graph_pattern] }
          -> { :replace_and_traverse,
             %InterpreterTerms.SymbolMatch{ symbol: :GroupOrUnionGraphPattern,
                                            submatches: [ group_graph_pattern ] } }
        _ -> { :continue }
      end
    end )
  end

  @doc """
  Removes FROM and FROM NAMED from QueryUnit.
  """
  def remove_from_statements( element ) do
    # We need to search for components which have a DatasetClause, and
    # remove it from where it might be.

    # TODO: this can be optimized by only searching the tree in
    # locations where this may be the case, rather than searching
    # everywhere.
    is_dataset_clause? = &match?(%InterpreterTerms.SymbolMatch{ symbol: :DatasetClause },&1)

    Manipulators.Basics.map_matches( element, fn (sym) ->
      case sym do
        %InterpreterTerms.SymbolMatch{ submatches: :none }  = sym ->
          { :continue }
        %InterpreterTerms.SymbolMatch{ submatches: matches } = sym ->
          if Enum.find( matches, is_dataset_clause? ) do
            { :replace_by,
              %{ sym | submatches: Enum.reject( matches, is_dataset_clause? ) } }
          else
            { :continue }
          end
        _ -> { :continue }
      end
    end )
  end

  @doc """
  Replaces the from_iri with the to_iri in the whole query.

  The from_iri string should be an Iri in the format in which it
  appears in the query (eg: <http://mu.semte.ch/sessions/24>).
  """
  def replace_iri( element, from_iri, to_iri ) do
    Manipulators.Basics.map_matches( element, fn (child) ->
      case child do
        %InterpreterTerms.SymbolMatch{ symbol: :iri, string: str } ->
          if str == from_iri do
            { :replace_and_traverse,
              %InterpreterTerms.SymbolMatch{
                symbol: :iri,
                submatches: [
                  %InterpreterTerms.SymbolMatch{
                    symbol: :IRIREF,
                    string: to_iri,
                    submatches: :none }
                ]
              } }
          else
            { :continue }
          end
        _ -> { :continue }
      end
    end )
  end
end
