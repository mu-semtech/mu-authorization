defmodule TermSelectors do
  alias GraphReasoner.Support.TermSelectors
  alias InterpreterTerms.SymbolMatch, as: Sym
  alias InterpreterTerms.WordMatch, as: Word

  @moduledoc """
  Supporting selectors for terms which did not readily belonged
  elsewhere.  These are terms that fall through our abstractions and
  we should manage to move these to other locations in the future.
  """

  @doc """
  Yields the term in the subexpression to which we should attach
  information.
  """
  def term_to_attach_info_to(%Sym{symbol: :PathPrimary, submatches: [%Word{word: "a"} = word]}) do
    word
  end

  def term_to_attach_info_to(%Sym{symbol: :PathPrimary, submatches: [%Sym{symbol: :iri} = iri]}) do
    iri
  end

  def term_to_attach_info_to(%Sym{symbol: :VarOrTerm, submatches: [%Sym{symbol: :Var} = var]}) do
    var
  end

  def term_to_attach_info_to(%Sym{
        symbol: :VarOrTerm,
        submatches: [%Sym{symbol: :GraphTerm, submatches: [%Sym{symbol: :iri} = iri]}]
      }) do
    iri
  end

  def term_to_attach_info_to(%Sym{} = symbol) do
    symbol
  end
end
