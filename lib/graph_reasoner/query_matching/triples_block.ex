alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word

defmodule GraphReasoner.QueryMatching.TriplesBlock do

  @moduledoc """
  Parses information from a TriplesBlock SymbolMatch.
  
  The idea behind this module is to keep it as simple as possible,
  mainly focussing on abstracting the verbose EBNF.
  """

  
  @doc """
  Assuming the supplied SymbolMatch contains only one simple triple,
  extract

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
            | maybe_a_dot ] }
  ) do
    case maybe_a_dot do
      [] -> nil
      [%Word{}] -> nil
      _ -> raise "TriplesBlock is not a single triple"
    end

    { subjectVarOrTerm,
      predicateElement,
      objectVarOrTerm }
  end
  
  @doc """
  Assuming the supplied SymbolMatch contains a simple triple, extract

  - subject: the VarOrTerm element
  - predicate: the PathPrimary element
  - object: the VarOrTerm element
  """
  def first_triple!(
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
            | _maybe_other_content ] }
  ) do

    { subjectVarOrTerm,
      predicateElement,
      objectVarOrTerm }
  end

  @doc """
  Overwrites the submatches of the parent_triples_block to contain only the supplied child_triples_block.
  """
  def set_child(
    %Sym{ symbol: :TriplesBlock, submatches: [ first_elt | _rest_elts ] } = parent_triples_block,
    %Sym{ symbol: :TriplesBlock } = child_triples_block
  ) do
    %{ parent_triples_block | submatches: [ first_elt, %Word{ word: "." }, child_triples_block ] }
  end

  @doc """
  Easy updating of the predicate of a TriplesBlock
  """
  def update_predicate( triples_block, new_predicate ) do
    Manipulators.DeepUpdates.update_deep_submatch(
      triples_block, new_predicate,
      [ :TriplesBlock, {:TriplesSameSubjectPath,1}, :PropertyListPathNotEmpty, :VerbPath, :Path, :PathAlternative, :PathSequence, :PathEltOrInverse, :PathElt ])
  end

  def predicate( triples_block ) do
    triples_block
    |> first_triple!
    |> elem(1)
  end

  def wrap_in_graph( triples_block, graph_uri ) do
    # Convert the TriplesBlock into a GraphPatternNotTriples>GraphGraphPattern>GroupGraphPattern>GroupGraphPatternSub>TriplesBlock
    # This last one can be inlined as a GroupGraphPattern>GroupGraphPatternSub may have many GraphPatternNotTriples subexpressions.

    %Sym{ symbol: :GraphPatternNotTriples, submatches: [
            %Sym{ symbol: :GraphGraphPattern, submatches: [
                    %Word{ word: "GRAPH" },
                    %Sym{ symbol: :VarOrIri, submatches: [
                            %Sym{ symbol: :iri, submatches: [
                                    %Sym{ symbol: :IRIREF,
                                          string: "<" <> graph_uri <> ">",
                                          submatches: :none }
                                  ] } ] },
                    %Sym{ symbol: :GroupGraphPattern,
                          submatches: [
                            %Word{ word: "{" },
                            %Sym{ symbol: :GroupGraphPatternSub,
                                  submatches: [
                                    triples_block
                                  ] },
                            %Word{ word: "}" }
                          ] } ] } ] }
  end
end


