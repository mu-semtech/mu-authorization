alias InterpreterTerms.Choice.Interpreter, as: ChoiceEmitter

defmodule ChoiceEmitter do
  defstruct option_generators: [], solutions: []

  def dispatch_emit(%ChoiceEmitter{solutions: [s | ss]} = gen) do
    {:ok, %{gen | solutions: ss}, s}
  end

  def dispatch_emit(%ChoiceEmitter{solutions: [], option_generators: []}) do
    {:fail}
  end

  def dispatch_emit(%ChoiceEmitter{solutions: [], option_generators: generators} = emitter) do
    # Emit a solution from each of the generators
    # Remove empty generators/results
    # Sort solutions by length
    # Emit with new solutions and new generators

    {new_solutions, new_generators} =
      generators
      |> Enum.map(&EbnfParser.Generator.emit/1)
      |> remove_empty_solutions
      |> sort_solutions
      |> split_solutions_and_generators

    dispatch_emit(%{emitter | solutions: new_solutions, option_generators: new_generators})
  end

  def remove_empty_solutions(solutions) do
    solutions
    |> Enum.reject( &match?({:fail},&1) )
  end

  defp sort_solutions(solutions) do
    solutions
    |> Enum.sort_by(fn {_, _, result} -> Generator.Result.length(result) end, &>=/2)
  end

  def split_solutions_and_generators(solutions) do
    {
      Enum.map(solutions, fn {_, _, solution} -> solution end),
      Enum.map(solutions, fn {_, generator, _} -> generator end)
    }
  end

  defimpl EbnfParser.Generator do
    def emit(%ChoiceEmitter{} = gen) do
      ChoiceEmitter.dispatch_emit(gen)
    end
  end
end
