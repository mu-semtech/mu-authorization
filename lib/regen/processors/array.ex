alias Regen.Processors.Array, as: Array
alias Regen.Status, as: State

# We probably need to do the work for the array again.  It's not great
# to reuse the code that already exists as it may well not fit our
# problem.  It is better to reconcile in a later step.

# How?
#
# An array should create a generator for the current element.  If this
# element yields a result, a generator should be built for the child
# elements of the array (it is likely best to use the Array generator
# for this).
#
# If the array generator has only one element, you can build a child
# generator and yield its result directly.  Your parent will combine
# the results if necessary.
#
# Children are required to combine the full match with a new status.
# It is ok to just yield that status as a result, and build upon it
# for further elements.  There is no need for a complex character
# match or anything of the likes.

defmodule Array do
  defstruct elements: [],
            state: %State{},
            child_generator: :none,
            rest_generator: :none,
            last_child_result: :none

  defimpl Regen.Protocol do
    def emit(%Array{} = array) do
      Array.walk(array)
    end
  end

  defp dispatch_generation(element, state) do
    Regen.Constructor.make(element, state)
  end

  defp emit(generator) do
    Regen.Protocol.emit(generator)
  end

  # there are no elements
  def walk(%Array{child_generator: :none, elements: []}) do
    {:fail}
  end

  # there is one element
  def walk(%Array{elements: [_]} = arr) do
    arr
    |> ensure_child_generator_exists
    |> emit_direct_child_result
  end

  # there are many elements
  def walk(%Array{} = arr) do
    case arr
         |> ensure_child_generator_exists
         |> ensure_child_result_exists do
      {:ok, arr_has_child_gen} ->
        arr_has_child_gen
        |> ensure_rest_generator_exists
        |> emit_nested_result

      _ ->
        {:fail}
    end
  end

  defp ensure_child_generator_exists(
         %Array{child_generator: :none, elements: [element | _], state: state} = arr
       ) do
    %{arr | child_generator: dispatch_generation(element, state)}
  end

  defp ensure_child_generator_exists(%Array{} = arr) do
    arr
  end

  defp ensure_child_result_exists(%Array{last_child_result: :none, child_generator: gen} = arr) do
    case emit(gen) do
      {:ok, new_gen, new_state} ->
        {:ok, %{arr | last_child_result: new_state, child_generator: new_gen}}

      _ ->
        {:fail}
    end
  end

  defp ensure_child_result_exists(%Array{} = arr) do
    arr
  end

  defp ensure_rest_generator_exists(
         %Array{rest_generator: :none, elements: [_ | rest], last_child_result: new_state} = arr
       ) do
    gen = %Array{elements: rest, state: new_state}

    %{arr | rest_generator: gen}
  end

  defp ensure_rest_generator_exists(%Array{} = arr) do
    arr
  end

  defp emit_direct_child_result(%Array{child_generator: gen} = arr) do
    case emit(gen) do
      {:ok, new_gen, result} ->
        {:ok, %{arr | child_generator: new_gen}, result}

      _ ->
        {:fail}
    end
  end

  defp emit_nested_result(%Array{rest_generator: gen} = arr) do
    case emit(gen) do
      {:ok, new_gen, result} ->
        {:ok, %{arr | rest_generator: new_gen}, result}

      _ ->
        walk(%{arr | last_child_result: :none, rest_generator: :none})
    end
  end
end
