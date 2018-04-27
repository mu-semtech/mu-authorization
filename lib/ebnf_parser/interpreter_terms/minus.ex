alias Generator.State, as: State

defmodule InterpreterTerms.Minus do
  defstruct [:left, :right, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %InterpreterTerms.Minus{ left: left, right: right, state: state } ) do
      %InterpreterTerms.Minus.Interpreter{
        state: state,
        left_generator: EbnfParser.GeneratorConstructor.dispatch_generation( left, state ),
        right_generator: EbnfParser.GeneratorConstructor.dispatch_generation( right, state )
      }
    end
  end
end

