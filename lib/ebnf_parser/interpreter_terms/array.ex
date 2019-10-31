defmodule InterpreterTerms.Array do
  alias Generator.State, as: State

  defstruct [:elements, {:state, %State{}}]

  @type t :: %InterpreterTerms.Array{
          elements: [EbnfParser.GeneratorConstructor.ebnf_term()],
          state: Generator.State.t()
        }

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
