alias Generator.State, as: State

defmodule State do
  @type t :: %State{
          chars: [String.grapheme()],
          syntax: EbnfParser.Sparql.syntax(),
          options: map()
        }

  defstruct chars: [], syntax: %{}, options: %{}

  @doc """
  Informs if the state is currently a terminal state, meaning it
  should be the last expanded state.
  """
  @spec is_terminal(t) :: boolean
  def is_terminal(%State{options: options}) do
    Map.get(options, :terminal)
  end

  @doc """
  Drops the spaces from the characters in a state, only updating th
  echars property.
  """
  @spec drop_spaces(t) :: t
  def drop_spaces(%State{chars: chars} = state) do
    %{state | chars: Enum.drop_while(chars, fn x -> x in [" ", "\t", "\n"] end)}
  end

  @spec split_off_whitespace(State.t()) :: {State.t(), String.t()}
  def split_off_whitespace(%State{chars: chars} = state) do
    {new_chars, drop_string} = cut_whitespace(chars)

    {%{state | chars: new_chars}, drop_string}
  end

  @doc """
  Cuts off whitespace from a set of strings.  Returns the new charlist
  and a string representation of the cut off whitespace.
  """
  def cut_whitespace(chars) do
    # Strip spaces from front
    {whitespace, rest} = Enum.split_while(chars, fn x -> x in [" ", "\t", "\n"] end)
    {rest, whitespace |> List.to_string()}
  end

  @spec chars_as_string(t) :: String.t()
  def chars_as_string(%State{chars: chars}) do
    to_string(chars)
  end
end
