defmodule Regen do
  @doc """
  Builds a generator for regenartion from the supplied (parsed) element.

  Starts scanning from the EBNF symbol <symbol>, which defaults to things that scan SPARQL queries.
  """
  def make_generator( element, symbol\\:QueryUnit ) do
    Regen.Constructor.make( { :symbol, symbol }, %Regen.Status{ elements: [element], syntax: Parser.parse_sparql } )
  end
end
