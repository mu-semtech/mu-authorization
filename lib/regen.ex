defmodule Regen do
  @doc """
  Builds a generator for regeneration from the supplied (parsed) element.

  Starts scanning from the EBNF symbol <symbol>, which defaults to things that scan SPARQL queries.
  """
  @spec make_generator(Parser.query(), atom) :: Regen.Constructor.t()
  def make_generator(element, symbol \\ :Sparql) do
    Regen.Constructor.make({:symbol, symbol}, %Regen.Status{
      elements: [element],
      syntax: Parser.sparql_syntax()
    })
  end

  def result(element, symbol \\ :Sparql) do
    element
    |> Regen.make_generator(symbol)
    |> Regen.Result.all()
    |> Enum.map(&Regen.Result.as_sparql/1)
    |> Enum.sort_by(&String.length/1, &>=/2)
    |> List.first()
  end
end
