defmodule InterpreterTerms.Choice.Impl do
  defstruct [:parsers]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Choice.Impl{parsers: options}, parsers, chars) do
      options
      |> Enum.flat_map(&EbnfParser.ParseProtocol.parse(&1, parsers, chars))
      |> post
    end

    defp post(results) do
      if Enum.all?(results, &Generator.Result.is_error?/1) do
        # Only best error could be useful
        results |> sort_solutions() |> Enum.take(1)
      else
        results |> Enum.reject(&Generator.Result.is_error?/1)
      end
    end

    defp sort_solutions(solutions) do
      solutions
      |> Enum.sort_by(&Generator.Result.length/1, &>=/2)
    end
  end
end

defmodule InterpreterTerms.Choice do
  defstruct [:options]

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
