defmodule InterpreterTerms.Some.Impl do
  defstruct [
    :parser
  ]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Some.Impl{parser: parser}, parsers, chars) do
      do_parse(
        # Actual base solution, parse zero times
        %Generator.Result{
          leftover: chars
        },
        parser,
        parsers
      )
      |> sort_solutions()
    end

    defp do_parse(
           %Generator.Result{
             leftover: chars
           } = base,
           parser,
           parsers
         ) do
      results = EbnfParser.ParseProtocol.parse(parser, parsers, chars)

      # Keep base to assure some solutions are valid
      # Also keep all parse paths open
      [
        base
        | results
          |> Enum.reject(&Generator.Result.is_error?/1)
          |> Enum.map(&Generator.Result.combine_results(base, &1))
          |> Enum.flat_map(&do_parse(&1, parser, parsers))
      ]
    end

    defp sort_solutions(solutions) do
      solutions
      |> Enum.sort_by(&Generator.Result.length/1, &>=/2)
    end
  end
end

defmodule InterpreterTerms.Some do
  alias Generator.State, as: State

  defstruct [:element, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Some{element: element, state: state}) do
      %InterpreterTerms.Some.Interpreter{
        element: element,
        state: state
      }
    end
  end

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Some{element: element}) do
      parser =
        element
        |> EbnfParser.GeneratorConstructor.to_term()
        |> EbnfParser.ParserProtocol.make_parser()

      %InterpreterTerms.Some.Impl{parser: parser}
    end
  end
end
