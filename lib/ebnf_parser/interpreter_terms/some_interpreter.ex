alias InterpreterTerms.Some.Interpreter, as: SomeEmitter

defmodule SomeEmitter do
  alias Generator.State, as: State
  alias Generator.Result, as: Result

  @type t :: %SomeEmitter{
          element: EbnfParser.GeneratorConstructor.rule(),
          state: State.t(),
          selfgenerator: EbnfParser.Generator.t() | :none,
          base_result: Result.t() | :none,
          restgenerator: EbnfParser.Generator.t() | :none,
          locked_states: [Result.t()]
        }

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
      SomeEmitter.emit(emitter)
    end
  end

  def emit(%SomeEmitter{} = some) do
    case some
         |> ensure_base_result
         |> ensure_selfgenerator_exists
         |> ensure_restgenerator_exists do
      {:ok, some} ->
        some
        |> emit_restgenerator_result

      {:ok, generator, result} ->
        {:ok, generator, result}

      _ ->
        {:fail}
    end
  end

  @spec ensure_base_result(t) :: t
  defp ensure_base_result(%SomeEmitter{state: %State{chars: chars}, base_result: :none} = some) do
    base_result = %Result{leftover: chars}
    %{some | base_result: base_result}
  end

  defp ensure_base_result(%SomeEmitter{} = some) do
    some
  end

  @spec ensure_selfgenerator_exists(t) :: t
  def ensure_selfgenerator_exists(
        %SomeEmitter{selfgenerator: :none, element: element, state: state} = some
      ) do
    %{some | selfgenerator: dispatch_generation(element, state)}
  end

  def ensure_selfgenerator_exists(%SomeEmitter{} = some) do
    some
  end

  @spec ensure_restgenerator_exists(t) ::
          {:ok, t} | {:ok, EbnfParser.Generator.t(), Result.t()} | {:fail}
  defp ensure_restgenerator_exists(
         %SomeEmitter{
           selfgenerator: selfgen,
           restgenerator: :none,
           state: state,
           base_result: base_result,
           locked_states: locked_states
         } = some
       ) do
    # When restgenerator is :none, we must generate a result from the
    # self generator, and create a new restgenerator based off of
    # that.
    case EbnfParser.Generator.emit(selfgen) do
      {:ok, new_selfgen, child_result} ->
        if locked_state?(some, combined_result(base_result, child_result)) do
          # if we are now in a locked state, skip it
          emit(%{some | selfgenerator: new_selfgen})
        else
          # generate a new result with our state as the new base state
          combined_child_result = combined_result(base_result, child_result)
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
        # TODO: Is this code-path broken?
        #
        # I think this code-path is broken.  We cannot simply emit a
        # result from here unless accepted by our calling function.
        #
        # In further reading, I believe the code-path may well be
        # correct.  We may emit to our parent that we have found a
        # result for our function, it is up to the consumer the
        # validate their own step to be valid.  Some has no
        # implication that any value must match.

        # Emit our own state as a result
        #
        # TODO: I have put locked_state back on here as I believe we
        # will otherwise yield duplicate states that will slow things
        # down.  If a fail is not allowed from here, we should figure
        # out how the generator should tackle this, it seems.
        #
        # TODO: We seemingly add ourself as a locked state too early
        # in the process, meaning we can't shortcircuit here.  Some
        # optimization is likely possible when optimizing this.

        # if locked_state?(some, base_result) do
        #   {:fail}
        # else
          {:ok, %InterpreterTerms.Nothing{}, base_result}
        # end
    end
  end

  defp ensure_restgenerator_exists(%SomeEmitter{} = some) do
    {:ok, some}
  end

  @spec emit_restgenerator_result(t) :: EbnfParser.Generator.response()
  defp emit_restgenerator_result(%SomeEmitter{restgenerator: restgen} = some) do
    case EbnfParser.Generator.emit(restgen) do
      {:ok, new_restgen, result} ->
        {:ok, %{some | restgenerator: new_restgen}, result}

      _ ->
        # Emit a new result from our selfgenerator and continue walking
        emit(%{some | restgenerator: :none})
    end
  end

  @spec locked_state?(t, Result.t()) :: boolean
  defp locked_state?(%SomeEmitter{locked_states: states}, result) do
    Enum.member?(states, result)
  end

  @spec dispatch_generation(EbnfParser.GeneratorConstructor.rule(), Generator.State.t()) ::
          EbnfParser.GeneratorProtocol.t()
  defp dispatch_generation(alpha, beta) do
    EbnfParser.GeneratorConstructor.dispatch_generation(alpha, beta)
  end

  @spec combined_result(Generator.Result.t(), Generator.Result.t()) :: Generator.Result.t()
  defp combined_result(base_result, child_result) do
    Result.combine_results(base_result, child_result)
  end
end
