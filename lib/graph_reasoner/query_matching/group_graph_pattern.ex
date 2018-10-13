alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word
alias Updates.QueryAnalyzer.Iri, as: Iri

defmodule GraphReasoner.QueryMatching.GroupGraphPattern do

  def only_triples_blocks?( symbol ) do
    # Ensure this only consists of TriplesBlock instances
    # >> disallowed keys: :SubSelect, :GraphPatternNotTriples (this
    #    is simplistic, some of these are ok)
    # TODO: make this approach smarter
    case Manipulators.Basics.map_matches( symbol,
          fn (match) ->
            case match do
              %Sym{ symbol: :SubSelect } -> 
                { :exit, :not_only_triples_block }
              %Sym{ symbol: :GraphPatternNotTriples } ->
                { :exit, :not_only_triples_block }
              _ -> { :continue }
            end
          end ) do
      { :exit, :not_only_triples_block } -> false
      _ -> true
    end
  end

  def only_triples_blocks!( symbol ) do
    true = only_triples_blocks?( symbol )
    symbol
  end


  def extract_triples_blocks( symbol ) do
    # Extract each of the TriplesBlock instances
    # >> Must yield a list of TriplesBlock elements
    #    with no nested TriplesBlocks elements inside of them
    { state, _mapped_query } =
      Manipulators.Basics.map_matches_with_state( [], symbol, fn ( state, match ) ->
        case match do
          %Sym{ symbol: :TriplesBlock } ->
            new_triples_blocks = extract_triples_blocks_from_triples_blocks( match )
            # IO.inspect( new_triples_blocks, label: "new triples blocks" )
            # IO.inspect( state, label: "old state" )

            { :skip, new_triples_blocks ++ state }
          _ -> { :continue, state }
        end
      end )

    state
  end

  defp extract_triples_blocks_from_triples_blocks( %Sym{ symbol: :TriplesBlock,
                                                        submatches: submatches } = triples_block )  do
    case submatches do
      [ _element ] -> [triples_block]
      [ _element, _word ] -> [triples_block]
      [ element, _word, next_triples_block ] ->
        [ %{ triples_block | submatches: [ element ] } | extract_triples_blocks_from_triples_blocks( next_triples_block ) ]
    end
  end

end
