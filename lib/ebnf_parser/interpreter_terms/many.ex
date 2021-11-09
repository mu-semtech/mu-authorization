defmodule InterpreterTerms.Many.Impl do
  defstruct [
    :parser
  ]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Many.Impl{parser: parser}, parsers, chars) do
      EbnfParser.ParseProtocol.parse(parser, parsers, chars)
      |> Enum.flat_map(&cont_parse(&1, parser, parsers))
    end

    defp cont_parse(%Generator.Result{leftover: leftover} = res, parser, parsers) do
      EbnfParser.ParseProtocol.parse(
        %InterpreterTerms.Some.Impl{parser: parser},
        parsers,
        leftover
      )
      |> Enum.map(&Generator.Result.combine_results(res, &1))
    end

    defp cont_parse(%Generator.Error{errors: errors} = res, _parsers, _xs) do
      [%{res | errors: [{:array} | errors]}]
    end
  end
end

defmodule InterpreterTerms.Many do
  defstruct [:element]

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
