defmodule GraphReasoner.QueryMatching.GraphPatternNotTriples do
  alias InterpreterTerms.SymbolMatch, as: Sym
  alias InterpreterTerms.WordMatch, as: Word

  def wrap_in_group_graph_pattern(%Sym{symbol: :GraphPatternNotTriples} = element) do
    %Sym{
      symbol: :GroupGraphPattern,
      submatches: [
        %Word{word: "{"},
        %Sym{symbol: :GroupGraphPatternSub, submatches: [element]},
        %Word{word: "}"}
      ]
    }
  end
end
