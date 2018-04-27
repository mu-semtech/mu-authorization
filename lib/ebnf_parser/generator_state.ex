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
    reduce_char_step = fn (char, x) ->
      if char in [" ","\t","\n"] do
        { :cnt, x + 1 }
      else
        { :skip, x }
      end
    end

    { _, drop_count } = Enum.reduce(
      chars, { :cnt, 0 }, fn
        (char, { :cnt, x }) -> reduce_char_step.( char, x )
        ( _, { _, x } ) -> { :skip, x }
      end )

    { Enum.drop(chars, drop_count),
      Enum.take(chars, drop_count) |> Enum.reduce( "", fn (a,b)  -> a <> b end ) }
  end

end
