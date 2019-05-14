defmodule Regen do
  @doc """
  Builds a generator for regenartion from the supplied (parsed) element.

  Starts scanning from the EBNF symbol <symbol>, which defaults to things that scan SPARQL queries.
  """
  def make_generator(element, symbol \\ :Sparql) do
    Regen.Constructor.make({:symbol, symbol}, %Regen.Status{
      elements: [element],
      syntax: Parser.parse_sparql()
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
