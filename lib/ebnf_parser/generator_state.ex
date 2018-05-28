alias Generator.State, as: State

defmodule State do
  @type t :: struct()

  defstruct chars: [], syntax: %{}, options: %{}

  def is_terminal( %State{ options: options } ) do
    Map.get( options, :terminal )
  end

  def drop_spaces( %State{ chars: chars } = state ) do
    %{ state
       | chars: Enum.drop_while( chars, fn x -> x in [" ","\t","\n"] end ) }
  end

  @spec split_off_whitespace( State ) :: { State.t, String.t }
  def split_off_whitespace( %State{ chars: chars } = state ) do
    { new_chars, drop_string } = cut_whitespace( chars )
    { %{ state | chars: new_chars }, drop_string }
  end

  def cut_whitespace( chars ) do
    # Strip spaces from front
    drop_count =
      Enum.reduce_while( chars, 0,
        fn (char, acc) ->
          if char in [" ", "\t", "\n"] do
            { :cont, acc + 1 }
          else
            { :halt, acc }
          end
        end )

    { Enum.drop(chars, drop_count),
      Enum.take(chars, drop_count) |> List.to_string }
  end

end
