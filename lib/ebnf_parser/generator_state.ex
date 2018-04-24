alias Generator.State, as: State

defmodule State do
  defstruct chars: [], syntax: %{}, options: %{}

  def is_terminal( %State{ options: options } ) do
    Map.get( options, :terminal )
  end

  def drop_spaces( %State{ chars: chars } = state ) do
    %{ state
       | chars: Enum.drop_while( chars, fn x -> x in [" ","\t","\n"] end ) }
  end
end
