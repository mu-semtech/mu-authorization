alias Generator.State, as: State

defmodule InterpreterTerms.Maybe do
  defstruct [:spec, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %InterpreterTerms.Maybe{ spec: spec, state: state } ) do
      %InterpreterTerms.Maybe.Interpreter{
        generator: EbnfParser.GeneratorConstructor.dispatch_generation( spec, state ),
        state: state
      }
    end
  end
end
