alias Generator.State, as: State

defmodule InterpreterTerms.Some do
  defstruct [:element, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %InterpreterTerms.Some{ element: element, state: state } ) do
      %InterpreterTerms.Some.Interpreter{
        element: element,
        state: state
      }
    end
  end
end
