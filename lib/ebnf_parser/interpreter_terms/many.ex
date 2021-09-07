defmodule InterpreterTerms.Many.Impl do
  defstruct [
    :parser
  ]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Many.Impl{parser: parser}, parsers, chars) do
      EbnfParser.ParseProtocol.parse(parser, parsers, chars)
      |> cont_parse(parser, parsers)
    end

    defp cont_parse(%Generator.Result{leftover: leftover} = res, parser, parsers) do
      result = EbnfParser.ParseProtocol.parse(
        %InterpreterTerms.Some.Impl{parser: parser},
        parsers,
        leftover
      )
      Generator.Result.combine_results(res, result)
    end

    defp cont_parse(%Generator.Error{errors: errors} = res, _parsers, _xs) do
      %{res | errors: [{:array} | errors]}
    end
  end
end

defmodule InterpreterTerms.Many do
  alias Generator.State, as: State

  defstruct [:element, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Many{element: element, state: state}) do
      %InterpreterTerms.Many.Interpreter{
        element: element,
        state: state,
        child_generator: EbnfParser.GeneratorConstructor.dispatch_generation(element, state)
      }
    end
  end

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Many{element: element}) do
      parser =
        element
        |> EbnfParser.GeneratorConstructor.to_term()
        |> EbnfParser.ParserProtocol.make_parser()

      %InterpreterTerms.Many.Impl{parser: parser}
    end
  end
end
