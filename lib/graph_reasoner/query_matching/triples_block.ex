alias InterpreterTerms.SymbolMatch, as: Sym

defmodule GraphReasoner.QueryMatching.TriplesBlock do

  @moduledoc """
  Parses information from a TriplesBlock SymbolMatch.
  
  The idea behind this module is to keep it as simple as possible,
  mainly focussing on abstracting the verbose EBNF.
  """

  
  @doc """

  Assuming the supplied SymbolMatch contains a simple triple, extract

  - subject: the VarOrTerm element
  - predicate: the PathPrimary element
  - object: the VarOrTerm element
  """
  def single_triple!(
    %Sym{ symbol: :TriplesBlock, submatches: [
            %Sym{ symbol: :TriplesSameSubjectPath, submatches: [
                    subjectVarOrTerm,
                    %Sym{ symbol: :PropertyListPathNotEmpty, submatches: [
                            %Sym{ symbol: :VerbPath, submatches: [
                                    %Sym{ symbol: :Path, submatches: [
                                            %Sym{ symbol: :PathAlternative, submatches: [
                                                    %Sym{ symbol: :PathSequence, submatches: [
                                                            %Sym{ symbol: :PathEltOrInverse, submatches: [
                                                                    %Sym{ symbol: :PathElt, submatches: [
                                                                            %Sym{ symbol: :PathPrimary } = predicateElement ] } ] } ] } ] } ] } ] },
                            %Sym{ symbol: :ObjectListPath, submatches: [
                                    %Sym{ symbol: :ObjectPath, submatches: [
                                            %Sym{ symbol: :GraphNodePath, submatches: [ objectVarOrTerm ] } ] } ] } ] } ] }
            | _maybe_a_dot ] }
  ) do
    { subjectVarOrTerm,
      predicateElement,
      objectVarOrTerm }
  end
  
  def update_predicate( triples_block, new_predicate ) do
    Manipulators.DeepUpdates.update_deep_submatch(
      triples_block, new_predicate,
      [ :TriplesBlock, {:TriplesSameSubjectPath,1}, :PropertyListPathNotEmpty, :VerbPath, :Path, :PathAlternative, :PathSequence, :PathEltOrInverse, :PathElt ])
  end

end


