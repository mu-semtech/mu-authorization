defmodule Manipulator do
  def apply_manipulators( query, manipulators ) do
    element = Parser.parse_query( query )
    |> Generator.Result.extract_element

    Enum.reduce( manipulators, element, fn (manipulator, elt) -> manipulator.(elt) end )
    |> Regen.make_generator
    |> Regen.Result.all
  end
end
