alias Generator.Result, as: Result
alias InterpreterTerms.Symbol.Interpreter, as: SymbolEmitter
# import EbnfParser.Generator, only: [emit: 1]
# import EbnfParser.GeneratorConstructor, only: [dispatch_generation: 2]

defmodule InterpreterTerms.SymbolMatch do
  defstruct [ :string, :symbol, :submatches ]

  defimpl String.Chars do
    def to_string( %InterpreterTerms.SymbolMatch{ string: str, symbol: symbol, submatches: sub } ) do
      { :symbol, "::#{symbol}::#{str}", Enum.map( sub, &String.Chars.to_string/1 ) }
    end
  end
end

defmodule SymbolEmitter do
  defstruct [ :generator, :symbol, :state, {:whitespace, ""} ]

  def emit( alpha ) do
    EbnfParser.Generator.emit( alpha )
  end

  # Generator protocol implementation dispatches to walk
  defimpl EbnfParser.Generator do
    def emit( %SymbolEmitter{ generator: gen, symbol: sym, whitespace: whitespace } = emitter ) do
      case SymbolEmitter.emit( gen ) do
        { :ok, gen, %Result{ match_construct: construct, matched_string: str } = result } ->
          { :ok,
            %{ emitter | generator: gen },
            %{ result |
               match_construct: [%InterpreterTerms.SymbolMatch{
                                    symbol: sym,
                                    string: whitespace <> str,
                                    submatches: construct }],
               matched_string: whitespace <> str               
            } }
        _ -> { :fail }
      end
    end
  end
end
