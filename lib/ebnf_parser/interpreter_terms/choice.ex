alias Generator.State, as: State
# import EbnfParser.GeneratorConstructor, only: [ {:dispatch_generation, 2} ]

defmodule InterpreterTerms.Choice do
  defstruct [:options, {:state, %State{}}]

  def dispatch_generation(alpha, beta) do
    EbnfParser.GeneratorConstructor.dispatch_generation(alpha, beta)
  end

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Choice{state: state, options: options}) do
      %InterpreterTerms.Choice.Interpreter{
        option_generators:
          Enum.map(options, fn option ->
            InterpreterTerms.Choice.dispatch_generation(option, state)
          end)
      }
    end
  end
end
