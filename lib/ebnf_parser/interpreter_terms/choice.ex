defmodule InterpreterTerms.Choice.Impl do
  alias Generator.State, as: State
  defstruct [:parsers]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Choice.Impl{parsers: options}, parsers, chars) do
      Enum.flat_map(options, &EbnfParser.ParseProtocol.parse(&1, parsers, chars)) |> post
    end

    def post(results) do
      if Enum.all?(results, &Generator.Result.is_error?/1) do
        base = %Generator.Error{
          errors: [:choice]
        }

        Enum.map(results, &Generator.Result.combine_results(base, &1))
      else
        results |> sort_solutions()
      end
    end

    defp sort_solutions(solutions) do
      solutions
      |> Enum.sort_by(&Generator.Result.length/1, &>=/2)
    end
  end
end

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

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Choice{options: options}) do
      parser_options =
        options
        |> Enum.map(&EbnfParser.GeneratorConstructor.to_term/1)
        |> Enum.map(&EbnfParser.ParserProtocol.make_parser/1)

      %InterpreterTerms.Choice.Impl{
        parsers: parser_options
      }
    end
  end
end
