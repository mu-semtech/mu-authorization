alias Generator.Result, as: Result
alias InterpreterTerms.Symbol.Interpreter, as: SymbolEmitter
# import EbnfParser.Generator, only: [emit: 1]
# import EbnfParser.GeneratorConstructor, only: [dispatch_generation: 2]

defmodule InterpreterTerms.SymbolMatch do
  defstruct [ :string, :symbol, { :submatches, :none } ]

  defimpl String.Chars do
    def to_string( %InterpreterTerms.SymbolMatch{ string: str, symbol: symbol, submatches: sub } ) do
      if sub == :none do
        { :symbol, "::#{symbol}::#{str}" }
      else
        { :symbol, "::#{symbol}::#{str}", Enum.map( sub, &String.Chars.to_string/1 ) }
      end
    end
  end
end

defmodule SymbolEmitter do
  defstruct [ :generator, :symbol, :state, {:whitespace, ""}, :emit_submatches ]

  def emit( alpha ) do
    EbnfParser.Generator.emit( alpha )
  end

  # Generator protocol implementation dispatches to walk
  defimpl EbnfParser.Generator do
    def emit( %SymbolEmitter{ generator: gen,
                              symbol: sym,
                              whitespace: whitespace,
                              emit_submatches: emit_submatches } = emitter ) do
      case SymbolEmitter.emit( gen ) do
        { :ok, gen, %Result{ match_construct: construct, matched_string: str } = result } ->
          match_construct =
            %InterpreterTerms.SymbolMatch{
              symbol: sym,
              string: whitespace <> str}
          match_construct = if emit_submatches
            do %{ match_construct | submatches: construct }
            else match_construct end

          { :ok,
            %{ emitter | generator: gen },
            %{ result |
               match_construct: [match_construct],
               matched_string: whitespace <> str               
            } }
        _ -> { :fail }
      end
    end
  end
end
