alias Generator.State, as: State

defmodule InterpreterTerms.Symbol do
  defstruct [:symbol, {:state, %Generator.State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %InterpreterTerms.Symbol{
          symbol: name,
          state: %Generator.State{ syntax: syntax, chars: chars, options: options } = state } ) do
      # Match rule
      { terminal, rule } = Map.get( syntax, name )

      # We should emit submatches when our _parents' state_ is not terminal
      emit_submatches = ! Generator.State.is_terminal( state )

      # Strip spaces from front
      { state, whitespace } = if Generator.State.is_terminal( state ) do
        { state, "" }
      else
        Generator.State.split_off_whitespace( state )
      end

      # Override terminal option
      new_options = Map.put( options, :terminal, terminal )

      # Create new state
      new_state = %{ state | options: new_options }
      # %State{ syntax: syntax, chars: new_chars, options: new_options }

      # Create generator
      child_generator = EbnfParser.GeneratorConstructor.dispatch_generation(
        rule, new_state
      )

      %InterpreterTerms.Symbol.Interpreter{
        symbol: name,
        state: new_state,
        generator: child_generator,
        whitespace: whitespace,
        emit_submatches: ! Generator.State.is_terminal( state )
      }
    end
  end
end

