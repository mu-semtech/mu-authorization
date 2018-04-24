alias Generator.State, as: State
import EbnfParser.GeneratorConstructor, only: [ {:dispatch_generation, 2} ]

defmodule InterpreterTerms.Choice do
  defstruct [:options, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %InterpreterTerms.Choice{ state: state, options: options } ) do
      %InterpreterTerms.Choice.Interpreter{
        option_generators: Enum.map( options, fn (option) -> dispatch_generation( option, state ) end )
      }
    end
  end
end
