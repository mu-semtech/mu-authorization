alias Generator.Result, as: Result
alias InterpreterTerms.Maybe.Interpreter, as: MaybeEmitter
alias Generator.State, as: State
# import EbnfParser.Generator, only: [emit: 1]
# import EbnfParser.GeneratorConstructor, only: [dispatch_generation: 2]

defmodule MaybeEmitter do
  defstruct [:generator, :state]

  # Generator protocol implementation dispatches to walk
  defimpl EbnfParser.Generator do
    def emit(%MaybeEmitter{generator: gen, state: %State{chars: chars}} = emitter) do
      case EbnfParser.Generator.emit(gen) do
        {:ok, gen, result} ->
          {:ok, %{emitter | generator: gen}, result}

        _ ->
          {:ok, %InterpreterTerms.Nothing{}, %Result{leftover: chars}}
      end
    end
  end
end
