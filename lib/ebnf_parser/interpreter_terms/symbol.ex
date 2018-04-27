alias Generator.State, as: State

defmodule InterpreterTerms.Symbol do
  defstruct [:symbol, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %InterpreterTerms.Symbol{
          symbol: name,
          state: %{ syntax: syntax, chars: chars, options: options } } ) do
      # Match rule
      { terminal, rule } = Map.get( syntax, name )

      # Strip spaces from front
      new_chars = if( ( ! Map.get(options, :terminal) ) and terminal ) do
        Enum.drop_while( chars, fn x -> x in [" ","\t","\n"] end )
      else
        chars
      end

      # Override terminal option
      new_options = Map.put( options, :terminal, terminal )

      # Create new state
      new_state = %State{ syntax: syntax, chars: new_chars, options: new_options }

      # Create generator
      child_generator = EbnfParser.GeneratorConstructor.dispatch_generation(
        rule, new_state
      )

      %InterpreterTerms.Symbol.Interpreter{
        symbol: name,
        state: new_state,
        generator: child_generator
      }
    end
  end
end

