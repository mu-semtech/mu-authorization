alias Generator.State, as: State

defmodule InterpreterTerms.Array do
  defstruct [:elements, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Array{elements: elements, state: state}) do
      # The list generator will have to generate a result for its
      # first option.  For each of the solutions in the first element
      # of the list, it will have to try all solutions of the child
      # elements.  This logic is handled in Array.Interpreter.
      %InterpreterTerms.Array.Interpreter{
        elements: elements,
        state: state
      }
    end
  end
end
