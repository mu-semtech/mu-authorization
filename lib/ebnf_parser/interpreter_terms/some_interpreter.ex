alias InterpreterTerms.Some.Interpreter, as: SomeEmitter

defmodule SomeEmitter do
  alias Generator.State, as: State
  alias Generator.Result, as: Result

  defstruct [
    :element,
    :state,
    {:selfgenerator, :none},
    {:base_result, :none},
    {:restgenerator, :none},
    {:locked_states, []}
  ]

  defimpl EbnfParser.Generator do
    def emit(%SomeEmitter{} = emitter) do
      SomeEmitter.walk(emitter)
    end
  end

  def walk(%SomeEmitter{} = some) do
    case some
         |> ensure_base_result
         |> ensure_selfgenerator_exists
         |> ensure_restgenerator_exists do
      {:ok, some} ->
        some
        |> emit_restgenerator_result

      {:ok, generator, result} ->
        {:ok, generator, result}

        # dialyzer is sure this cannot occur.  Leaving it for future
        # implementations
        # _ ->
        #   yield_none_result(some)
    end
  end

  defp ensure_base_result(%SomeEmitter{state: %State{chars: chars}, base_result: :none} = some) do
    base_result = %Result{leftover: chars}
    %{some | base_result: base_result}
  end

  # TODO: merge the following two states?  both yield some, regardless
  # of the further state
  defp ensure_base_result(%SomeEmitter{state: %State{chars: _chars}} = some) do
    some
  end

  defp ensure_base_result(%SomeEmitter{} = some) do
    some
  end

  # defp yield_none_result(%SomeEmitter{state: %State{chars: chars}}) do
  #   {:ok, %InterpreterTerms.Nothing{}, %Result{leftover: chars}}
  # end

  def ensure_selfgenerator_exists(
        %SomeEmitter{selfgenerator: :none, element: element, state: state} = some
      ) do
    %{some | selfgenerator: dispatch_generation(element, state)}
  end

  def ensure_selfgenerator_exists(%SomeEmitter{} = some) do
    some
  end

  defp ensure_restgenerator_exists(
         %SomeEmitter{
           selfgenerator: selfgen,
           restgenerator: :none,
           state: state,
           base_result: base_result,
           locked_states: locked_states
         } = some
       ) do
    case EbnfParser.Generator.emit(selfgen) do
      {:ok, new_selfgen, child_result} ->
        if locked_state?(some, combined_result(some, child_result)) do
          # if we are now in a locked state, skip it
          walk(%{some | selfgenerator: new_selfgen})
        else
          # generate a new result with our state as the new base state
          combined_child_result = combined_result(some, child_result)
          %{leftover: leftover} = child_result

          {:ok,
           %{
             some
             | restgenerator: %{
                 some
                 | state: %{state | chars: leftover},
                   selfgenerator: :none,
                   restgenerator: :none,
                   base_result: combined_child_result,
                   locked_states: [combined_child_result | locked_states]
               },
               selfgenerator: new_selfgen
           }}
        end

      _ ->
        # TODO: I think this code-path is broken.  We cannot simply
        # emit a result from here unless accepted by our calling
        # function.

        # Emit our own state as a result
        # if locked_state?( some, base_result ) do
        #   { :fail }
        # else
        {:ok, %InterpreterTerms.Nothing{}, base_result}
        # end
    end
  end

  defp ensure_restgenerator_exists(%SomeEmitter{} = some) do
    {:ok, some}
  end

  defp emit_restgenerator_result(%SomeEmitter{restgenerator: restgen} = some) do
    case EbnfParser.Generator.emit(restgen) do
      {:ok, new_restgen, result} ->
        {:ok, %{some | restgenerator: new_restgen}, result}

      _ ->
        # Emit a new result from our selfgenerator and continue walking
        walk(%{some | restgenerator: :none})
    end
  end

  defp locked_state?(%SomeEmitter{locked_states: states}, result) do
    Enum.member?(states, result)
  end

  defp dispatch_generation(alpha, beta) do
    EbnfParser.GeneratorConstructor.dispatch_generation(alpha, beta)
  end

  defp combined_result(%SomeEmitter{base_result: base_result}, child_result) do
    Result.combine_results(base_result, child_result)
  end
end
