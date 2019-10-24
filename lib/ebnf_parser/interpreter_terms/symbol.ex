defmodule InterpreterTerms.Symbol do
  alias Generator.State, as: State

  defstruct [:symbol, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Symbol{
          symbol: name,
          state: %State{syntax: syntax, options: options} = state
        }) do
      # Match rule
      {terminal, rule} = Map.get(syntax, name)

      # Strip spaces from front
      {state, whitespace} =
        if State.is_terminal(state) do
          {state, ""}
        else
          State.split_off_whitespace(state)
        end

      # We should emit submatches when our own state is not terminal
      emit_submatches = !terminal

      # Override terminal option
      new_options = Map.put(options, :terminal, terminal)

      # Create new state
      new_state = %{state | options: new_options}
      # %State{ syntax: syntax, chars: new_chars, options: new_options }

      # Create generator
      child_generator =
        EbnfParser.GeneratorConstructor.dispatch_generation(
          rule,
          new_state
        )

      %InterpreterTerms.Symbol.Interpreter{
        symbol: name,
        state: new_state,
        generator: child_generator,
        whitespace: whitespace,
        emit_submatches: emit_submatches
      }
    end
  end
end
