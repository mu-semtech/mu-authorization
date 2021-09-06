defmodule InterpreterTerms.Minus.Impl do
  defstruct [:left, :right]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Minus.Impl{left: left, right: right}, parsers, chars) do
      left_res = EbnfParser.ParseProtocol.parse(left, parsers, chars) |> MapSet.new()
      right_res = EbnfParser.ParseProtocol.parse(right, parsers, chars) |> MapSet.new()

      MapSet.difference(left_res, right_res)
      |> Enum.into([])
    end
  end
end

defmodule InterpreterTerms.Minus do
  alias Generator.State, as: State

  defstruct [:left, :right, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Minus{left: left, right: right, state: state}) do
      %InterpreterTerms.Minus.Interpreter{
        state: state,
        left_generator: EbnfParser.GeneratorConstructor.dispatch_generation(left, state),
        right_generator: EbnfParser.GeneratorConstructor.dispatch_generation(right, state)
      }
    end
  end

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
