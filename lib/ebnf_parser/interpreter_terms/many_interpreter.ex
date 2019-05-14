alias Generator.Result, as: Result
alias InterpreterTerms.Many.Interpreter, as: ManyEmitter
alias InterpreterTerms.Some, as: Some
# import EbnfParser.Generator, only: [emit: 1]
# import EbnfParser.GeneratorConstructor, only: [dispatch_generation: 2]

defmodule ManyEmitter do
  defstruct [
    :element,
    :state,
    # generator for the first step.
    :child_generator,
    # generator which emits for
    {:some_generator, :none},
    # all the next steps.
    # contains the result of our
    {:child_result, :none}
  ]

  # child, for combinatory
  # purposes.

  def emit(generator) do
    EbnfParser.Generator.emit(generator)
  end

  def walk(%ManyEmitter{child_result: :none, child_generator: generator} = emitter) do
    # emit a new child result
    case emit(generator) do
      {:ok, state, result} ->
        emitter
        |> Map.put(:child_result, {:ok, state, result})
        |> Map.put(:child_generator, state)
        |> walk

      _ ->
        {:fail}
    end
  end

  def walk(
        %ManyEmitter{
          child_result: {:ok, _, %Result{leftover: leftover}},
          some_generator: :none,
          element: element,
          state: state
        } = emitter
      ) do
    emitter
    |> Map.put(
      :some_generator,
      EbnfParser.GeneratorProtocol.make_generator(%Some{
        element: element,
        state: %{state | chars: leftover}
      })
    )
    |> walk
  end

  def walk(
        %ManyEmitter{child_result: {:ok, _, child_result}, some_generator: some_generator} =
          emitter
      ) do
    case emit(some_generator) do
      {:ok, some_state, some_result} ->
        {:ok, %{emitter | some_generator: some_state},
         Result.combine_results(child_result, some_result)}

      _ ->
        %{emitter | child_result: :none, some_generator: :none}
        |> walk
    end
  end

  defimpl EbnfParser.Generator do
    def emit(%ManyEmitter{} = emitter) do
      ManyEmitter.walk(emitter)
    end
  end
end
