alias Regen.Processors.Choice, as: Choice
alias Regen.Status, as: State
alias Regen.Result, as: Result

# The construction of the emitter is clean.  We will use a similar
# approach.
#
# First we build a generator for each of the options.  We emit a
# result for each of them and discard generators that failed.  As long
# as there are results, we emit one of the results.  As long as there
# are generators, we keep generating results.

defmodule Choice do
  defstruct [ options: [], state: %State{}, option_generators: :none, generated_options: [] ]

  defimpl Regen.Protocol do
    def emit( %Choice{} = choice ) do
      Choice.walk_choice( choice )
    end
  end

  def walk_choice(%Choice{} = choice) do
    choice
    |> ensure_generators
    |> ensure_generated_options
    |> emit_result
  end

  defp dispatch_generation( element, state ) do
    Regen.Constructor.make( element, state )
  end

  defp emit( generator ) do
    Regen.Protocol.emit( generator )
  end

  defp ensure_generators( %Choice{option_generators: :none, options: options, state: state } = choice ) do
    %{ choice |
       option_generators: Enum.map( options, fn (o) -> dispatch_generation( o, state ) end ) }
  end

  defp ensure_generators( %Choice{} = choice ) do
    choice
  end

  defp ensure_generated_options( %Choice{ option_generators: generators, generated_options: [] } = choice ) do
    { new_solutions, new_generators } =
      generators
      |> Enum.map( &emit/1 )
      |> InterpreterTerms.Choice.Interpreter.remove_empty_solutions
      |> sort_solutions
      |> InterpreterTerms.Choice.Interpreter.split_solutions_and_generators

    %{ choice |
       generated_options: new_solutions,
       option_generators: new_generators }
  end

  defp ensure_generated_options( %Choice{} = choice ) do
    choice
  end

  defp emit_result( %Choice{ generated_options: [option|rest] } = choice ) do
    {:ok, %{ choice | generated_options: rest }, option }
  end

  defp emit_result( %Choice{ generated_options: [], option_generators: []} ) do
    { :fail }
  end

  defp sort_solutions( solutions ) do
    solutions
    |> Enum.sort_by( fn ({_, _, %Regen.Status{elements: elts}}) -> Enum.count( elts ) end )
  end

end
