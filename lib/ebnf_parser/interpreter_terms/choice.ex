defmodule InterpreterTerms.Choice do
  alias Generator.State, as: State
  # import EbnfParser.GeneratorConstructor, only: [ {:dispatch_generation, 2} ]

  defstruct [:options, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Choice{state: state, options: options}) do
      %InterpreterTerms.Choice.Interpreter{
        option_generators: Enum.map(options, &dispatch_generation(&1, state))
      }
    end

    defp dispatch_generation(alpha, beta) do
      EbnfParser.GeneratorConstructor.dispatch_generation(alpha, beta)
    end
  end
end
