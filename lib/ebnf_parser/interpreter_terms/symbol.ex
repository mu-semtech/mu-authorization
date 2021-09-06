defmodule InterpreterTerms.Symbol.Impl do
  alias Generator.Result, as: Result
  alias Generator.State, as: State

  defstruct [:symbol]

  defimpl EbnfParser.ParseProtocol do
    def parse(
          %InterpreterTerms.Symbol.Impl{
            symbol: symbol
          },
          parsers,
          chars
        ) do
      {new_chars, whitespace} = State.cut_whitespace(chars)

      {child_parser, is_term} = Map.get(parsers, symbol)

      EbnfParser.ParseProtocol.parse(child_parser, parsers, new_chars)
      |> Enum.map(&cont_parse(&1, symbol, whitespace, is_term))
    end

    defp cont_parse(
           %Generator.Result{match_construct: construct, matched_string: str} = result,
           symbol,
           whitespace,
           is_term
         ) do
      match_construct = %InterpreterTerms.SymbolMatch{
        symbol: symbol,
        whitespace: whitespace,
        # TODO don't add whitespace for terminal symbols
        string: whitespace <> str
      }

      match_construct =
        if is_term do
          match_construct
        else
          %{match_construct | submatches: construct}
        end

      %{result | match_construct: [match_construct], matched_string: whitespace <> str}
    end

    defp cont_parse(
           %Generator.Error{
             errors: errors
           } = res,
           symbol,
           _whitespace,
           _is_term
         ) do
      %{res | errors: [{:symbol, symbol} | errors]}
    end
  end
end

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

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Symbol{
          symbol: name
        }) do
      %InterpreterTerms.Symbol.Impl{
        symbol: name
      }
    end
  end
end
