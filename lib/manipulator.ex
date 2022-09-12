defmodule Manipulators do
  require Logger

  @spec apply_manipulators(Parser.unparsed_query(), any) :: any
  def apply_manipulators(query, manipulators) do
    {_, element} = Parser.parse_query_first(query)

    Enum.reduce(manipulators, element, fn manipulator, elt -> manipulator.(elt) end)
    |> Regen.make_generator()
    |> Regen.Result.all()
    |> Enum.map(&Regen.Result.as_sparql/1)
    |> Enum.map(fn sparql_result -> Logger.debug(sparql_result) end)
  end
end
