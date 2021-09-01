defmodule InterpreterTerms.Array.Impl do
  defstruct [:elements]

  defimpl EbnfParser.ParseProtocol do
    def parse(
          %InterpreterTerms.Array.Impl{
            elements: parsers
          },
          chars
        ) do
      InterpreterTerms.Array.Impl.parse_things(parsers, chars)
    end
  end

  def parse_things([], chars) do
    [%Generator.Result{leftover: chars}]
  end

  def parse_things([x], chars) do
    EbnfParser.ParseProtocol.parse(x, chars)
  end

  def parse_things([x | xs], chars) do
    case EbnfParser.ParseProtocol.parse(x, chars) do
      {:fail} ->
        {:fail}

      parsed ->
        parsed
        |> Enum.flat_map(fn %Generator.Result{leftover: leftover} = res ->
          parse_things(xs, leftover) |> Enum.map(&combine_results(res, &1))
        end)
    end
  end

  defp combine_results(base_result, new_result) do
    # Combines two results for a list match.  The first supplied
    # result is the one that was generated earlier.
    Generator.Result.combine_results(base_result, new_result)
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
    def make_parser(%InterpreterTerms.Array{elements: items}, syntax) do
      parsers =
        items
        |> Enum.map(&EbnfParser.GeneratorConstructor.to_term(&1, %State{}))
        |> Enum.map(&EbnfParser.ParserProtocol.make_parser(&1, syntax))

      %InterpreterTerms.Array.Impl{
        elements: parsers
      }
    end
  end
end
