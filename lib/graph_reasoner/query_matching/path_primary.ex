alias InterpreterTerms.SymbolMatch, as: Sym
alias Updates.QueryAnalyzer.Iri, as: Iri

defmodule GraphReasoner.QueryMatching.PathPrimary do
  @moduledoc """
  Helpers to make sense of a PathPrimary.
  """

  @doc """
  Returns an Iri object for the supplied :PathPrimary, or crashes if
  it can not achieve that.
  """
  def iri!(%Sym{symbol: :PathPrimary, submatches: [submatch]}) do
    Iri.from_symbol(submatch)
  end

  def iri!(%Sym{symbol: :PathPrimary, string: str}) do
    # We also support the variant where the PathPrimary was not
    # correctly rewritten to something understood by Iri, as we
    # suspect this may occur when users rewrite the actual query.
    Iri.from_iri_string(str)
  end

  def iri!(%Sym{symbol: :PathPrimary, submatches: [submatch]}, prologue_info) do
    Iri.from_symbol(submatch, prologue_info)
  end
end
