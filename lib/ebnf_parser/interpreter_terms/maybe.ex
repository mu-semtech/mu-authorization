defmodule InterpreterTerms.Maybe.Impl do
  alias Generator.Result, as: Result

  defstruct [:parser]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Maybe.Impl{parser: parser}, parsers, chars) do
      xs = EbnfParser.ParseProtocol.parse(parser, parsers, chars)

      [%Result{leftover: chars} | xs]
      |> Enum.reject(&Generator.Result.is_error?/1)
    end
  end
end

defmodule InterpreterTerms.Maybe do
  defstruct [:spec]

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Maybe{spec: spec}) do
      %InterpreterTerms.Maybe.Impl{
        parser:
          EbnfParser.GeneratorConstructor.to_term(spec)
          |> EbnfParser.ParserProtocol.make_parser()
      }
    end
  end
end
