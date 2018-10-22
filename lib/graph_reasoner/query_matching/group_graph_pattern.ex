alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word
alias Updates.QueryAnalyzer.Iri, as: Iri

defmodule GraphReasoner.QueryMatching.GroupGraphPattern do
  require Manipulators.Basics

  def only_triples_blocks?( symbol ) do
    # Ensure this only consists of TriplesBlock instances
    # >> disallowed keys: :SubSelect, :GraphPatternNotTriples (this
    #    is simplistic, some of these are ok)
    # TODO: make this approach smarter

    map_result =
      Manipulators.Basics.do_map( symbol, submatch ) do
        :SubSelect -> { :exit, :not_only_triples_block }
        :GroupGraphPatternNotTriples -> { :exit, :not_only_triples_block }
      end

    not match?( { :exit, :not_only_triples_block }, map_result )
  end

  def only_triples_blocks!( symbol ) do
    true = only_triples_blocks?( symbol )
    symbol
  end


  def extract_triples_blocks( symbol ) do
    # Extract each of the TriplesBlock instances
    # >> Must yield a list of TriplesBlock elements
    #    with no nested TriplesBlocks elements inside of them

    # TODO: move this function to
    # GraphReasoner.QueryMatching.TriplesBlock or similar to indicate
    # its generic nature.
    Manipulators.Basics.do_state_map( { [], symbol }, { state, match } ) do
      :TriplesBlock ->
        new_triples_blocks = extract_triples_blocks_from_triples_block( match )
        { :skip, new_triples_blocks ++ state }
    end
    |> elem(0)
  end

  defp extract_triples_blocks_from_triples_block( %Sym{ symbol: :TriplesBlock,
                                                        submatches: submatches } = triples_block )  do
    case submatches do
      [ _element ] -> [triples_block]
      [ _element, _word ] -> [triples_block]
      [ element, _word, next_triples_block ] ->
        [ %{ triples_block | submatches: [ element ] } | extract_triples_blocks_from_triples_block( next_triples_block ) ]
    end
  end

end
