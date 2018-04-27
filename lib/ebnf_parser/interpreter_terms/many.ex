alias Generator.State, as: State

# defmodule InterpreterTerms.Nothing.Interpreter do
# end

defmodule InterpreterTerms.Many do
  defstruct [:element, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %InterpreterTerms.Many{ element: element, state: state } ) do
      %InterpreterTerms.Many.Interpreter{
        element: element,
        state: state,
        child_generator: EbnfParser.GeneratorConstructor.dispatch_generation( element, state )
      }
    end
  end
end
