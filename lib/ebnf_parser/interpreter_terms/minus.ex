defmodule InterpreterTerms.Minus.Impl do
  defstruct [:left, :right]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Minus.Impl{left: left, right: right}, parsers, chars) do
      left_res = EbnfParser.ParseProtocol.parse(left, parsers, chars) |> MapSet.new()
      right_res = EbnfParser.ParseProtocol.parse(right, parsers, chars) |> MapSet.new()

      results =
        MapSet.difference(left_res, right_res)
        |> Enum.into([])

      #
      # |> List.first(%Generator.Error{
      #   errors: [:no_minus]
      # })

      if Enum.all?(results, &Generator.Result.is_error?/1) do
        # Only best error could be useful
        results |> sort_solutions() |> Enum.take(1)
      else
        results
      end
    end

    defp sort_solutions(solutions) do
      solutions
      |> Enum.sort_by(&Generator.Result.length/1, &>=/2)
    end
  end
end

defmodule InterpreterTerms.Minus do
  defstruct [:left, :right]

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Minus{left: left, right: right}) do
      %InterpreterTerms.Minus.Impl{
        left:
          EbnfParser.GeneratorConstructor.to_term(left)
          |> EbnfParser.ParserProtocol.make_parser(),
        right:
          EbnfParser.GeneratorConstructor.to_term(right)
          |> EbnfParser.ParserProtocol.make_parser()
      }
    end
  end
end
