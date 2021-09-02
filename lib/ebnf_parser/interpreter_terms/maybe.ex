defmodule InterpreterTerms.Maybe.Impl do
  alias Generator.Result, as: Result
  alias Generator.State, as: State

  defstruct [:parser]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Maybe.Impl{parser: parser}, parsers, chars) do
      children = EbnfParser.ParseProtocol.parse(parser, parsers, chars)

      this_res = %Result{leftover: chars}

      [this_res | children] |> Enum.map(&extend_with_error/1)
    end

    defp extend_with_error(%Generator.Error{errors: errors} = res) do
      %{res | errors: [{:maybe} | errors]}
    end

    defp extend_with_error(%Generator.Result{} = res) do
      res
    end
  end
end

defmodule InterpreterTerms.Maybe do
  alias Generator.State, as: State

  defstruct [:spec, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Maybe{spec: spec, state: state}) do
      %InterpreterTerms.Maybe.Interpreter{
        generator: EbnfParser.GeneratorConstructor.dispatch_generation(spec, state),
        state: state
      }
    end
  end

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
