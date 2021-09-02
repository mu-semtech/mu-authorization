defmodule InterpreterTerms.Some.Impl do
  defstruct [
    :parser
  ]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Some.Impl{parser: parser}, parsers, chars) do
      do_parse(
        %Generator.Result{
          leftover: chars
        },
        parser,
        parsers
      )
    end

    defp do_parse(
           %Generator.Result{
             leftover: chars
           } = base,
           parser,
           parsers
         ) do
      results = EbnfParser.ParseProtocol.parse(parser, parsers, chars)
      good = results |> Enum.reject(&Generator.Result.is_error?/1)

      if Enum.empty?(good) do
        [base]
      else
        good
        |> Enum.map(&Generator.Result.combine_results(base, &1))
        |> Enum.flat_map(&do_parse(&1, parser, parsers))
      end
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
