defmodule InterpreterTerms.Array.Impl do
  defstruct [:elements]

  defimpl EbnfParser.ParseProtocol do
    def parse(
          %InterpreterTerms.Array.Impl{
            elements: items
          },
          parsers,
          chars
        ) do
      parse_things(items, parsers, chars)
    end

    defp parse_things([], _parsers, chars) do
      [%Generator.Result{leftover: chars}]
    end

    defp parse_things([x | xs], parsers, chars) do
      EbnfParser.ParseProtocol.parse(x, parsers, chars)
      |> Enum.flat_map(&cont_parse(&1, parsers, xs))
    end

    defp cont_parse(%Generator.Result{leftover: leftover} = res, parsers, xs) do
      parse_things(xs, parsers, leftover)
      |> Enum.map(&Generator.Result.combine_results(res, &1))
    end

    defp cont_parse(%Generator.Error{} = res, _parsers, _xs) do
      [res]
    end
  end
end

defmodule InterpreterTerms.Array do
  alias Generator.State, as: State

  defstruct [:elements, {:state, %State{}}]

  # @type t :: %InterpreterTerms.Array{
  #         elements: [EbnfParser.GeneratorConstructor.ebnf_term()],
  #         state: Generator.State.t()
  #       }

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Array{elements: elements, state: state}) do
      # The list generator will have to generate a result for its
      # first option.  For each of the solutions in the first element
      # of the list, it will have to try all solutions of the child
      # elements.  This logic is handled in Array.Interpreter.
      %InterpreterTerms.Array.Interpreter{
        elements: elements,
        state: state
      }
    end
  end

  # ----------------------------------------------------------------------------------------------------
  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Array{elements: items}) do
      parsers =
        items
        |> Enum.map(&EbnfParser.GeneratorConstructor.to_term(&1))
        |> Enum.map(&EbnfParser.ParserProtocol.make_parser/1)

      %InterpreterTerms.Array.Impl{
        elements: parsers
      }
    end
  end
end
