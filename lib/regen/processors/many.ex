alias Regen.Processors.Many, as: Many

defmodule Many do
  alias Regen.Processors.Some, as: Some
  alias Regen.Status, as: State

  defstruct [:element, {:state, %State{}}, {:self_generator, :none}, {:rest_generator, :none}]

  defimpl Regen.Protocol do
    def emit(%Many{} = many) do
      Many.walk(many)
    end
  end

  def walk(%Many{} = many) do
    case many
         |> ensure_self_generator
         |> ensure_rest_generator do
      {:ok, many} ->
        many
        |> emit_rest_result

      _ ->
        {:fail}
    end
  end

  defp ensure_self_generator(%Many{element: elt, self_generator: :none, state: state} = many) do
    %{many | self_generator: Regen.Constructor.make(elt, state)}
  end

  defp ensure_self_generator(%Many{} = many) do
    many
  end

  defp ensure_rest_generator(
         %Many{rest_generator: :none, self_generator: self_gen, element: elt} = many
       ) do
    case Regen.Protocol.emit(self_gen) do
      {:ok, new_self_gen, result} ->
        rest_generator =
          %Some{}
          |> Map.put(:element, elt)
          |> Map.put(:state, result)

        {:ok, %{many | rest_generator: rest_generator, self_generator: new_self_gen}}

      _ ->
        {:fail}
    end
  end

  defp ensure_rest_generator(%Many{} = many) do
    {:ok, many}
  end

  defp emit_rest_result(%Many{rest_generator: rest_gen} = many) do
    case Regen.Protocol.emit(rest_gen) do
      {:ok, new_rest_gen, result} ->
        {:ok, %{many | rest_generator: new_rest_gen}, result}

      _ ->
        many
        |> Map.put(:rest_generator, :none)
        |> walk
    end
  end
end
