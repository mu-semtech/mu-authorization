alias Generator.Result, as: Result
alias InterpreterTerms.Symbol.Interpreter, as: SymbolEmitter
# import EbnfParser.Generator, only: [emit: 1]
# import EbnfParser.GeneratorConstructor, only: [dispatch_generation: 2]

defmodule SymbolEmitter do
  defstruct [ :generator, :symbol, :state ]

  def emit( alpha ) do
    EbnfParser.Generator.emit( alpha )
  end

  # Generator protocol implementation dispatches to walk
  defimpl EbnfParser.Generator do
    def emit( %SymbolEmitter{ generator: gen, symbol: sym } = emitter ) do
      case SymbolEmitter.emit( gen ) do
        { :ok, gen, %Result{ match_construct: construct, matched_string: str } = result } ->
          { :ok,
            %{ emitter | generator: gen },
            %{ result | match_construct: [{ sym, str, construct }] } }
        _ -> { :fail }
        # { :ok, gen, result } ->
        #   { :ok, %{ emitter | generator: gen }, result }
        # _ -> {:fail}
      end
    end
  end
end
