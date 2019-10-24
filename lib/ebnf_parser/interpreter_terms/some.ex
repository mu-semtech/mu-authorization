defmodule InterpreterTerms.Some do
  alias Generator.State, as: State

  defstruct [:element, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Some{element: element, state: state}) do
      %InterpreterTerms.Some.Interpreter{
        element: element,
        state: state
      }
    end
  end
end
