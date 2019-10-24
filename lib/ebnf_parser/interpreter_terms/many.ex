defmodule InterpreterTerms.Many do
  alias Generator.State, as: State

  defstruct [:element, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Many{element: element, state: state}) do
      %InterpreterTerms.Many.Interpreter{
        element: element,
        state: state,
        child_generator: EbnfParser.GeneratorConstructor.dispatch_generation(element, state)
      }
    end
  end
end
