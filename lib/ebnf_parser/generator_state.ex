alias Generator.State, as: State

defmodule State do
  @doc """
  Cuts off whitespace from a set of strings.  Returns the new charlist
  and a string representation of the cut off whitespace.
  """
  def cut_whitespace(chars) do
    # Strip spaces from front
    {whitespace, rest} = Enum.split_while(chars, fn x -> x in [" ", "\t", "\n"] end)
    {rest, whitespace |> List.to_string()}
  end
end
