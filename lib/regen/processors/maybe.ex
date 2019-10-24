alias Regen.Processors.Maybe, as: Maybe

defmodule Maybe do
  alias Regen.Status, as: State

  defstruct [:element, {:state, %State{}}, {:self_generator, :none}]

  defimpl Regen.Protocol do
    def emit(%Maybe{} = maybe) do
      Maybe.walk(maybe)
    end
  end

  def walk(%Maybe{} = maybe) do
    maybe
    |> ensure_self_generator
    |> emit_result
  end

  def ensure_self_generator(%Maybe{self_generator: :none, element: elt, state: state} = maybe) do
    %{maybe | self_generator: Regen.Constructor.make(elt, state)}
  end

  def ensure_self_generator(%Maybe{} = maybe) do
    maybe
  end

  def emit_result(%Maybe{self_generator: gen, state: state} = maybe) do
    case Regen.Protocol.emit(gen) do
      {:ok, new_self_gen, result} ->
        {:ok, %{maybe | self_generator: new_self_gen}, result}

      _ ->
        {:ok, %Regen.Processors.None{}, state}
    end
  end
end
