alias Generator.Result, as: Result
alias InterpreterTerms.Symbol.Interpreter, as: SymbolEmitter

defmodule InterpreterTerms.SymbolMatch do
  defstruct [:string, :symbol, {:submatches, :none}, {:whitespace, ""}, {:external, %{}}]

  defimpl Inspect do
    def inspect(%InterpreterTerms.SymbolMatch{} = dict, opts) do
      {:doc_group,
       {:doc_cons,
        {:doc_nest,
         {:doc_cons, "%InterpreterTerms.SymbolMatch{",
          {:doc_cons, {:doc_break, "", :strict},
           {:doc_cons,
            {:doc_cons,
             {:doc_cons, "symbol:",
              {:doc_cons, " ", Inspect.inspect(Map.get(dict, :symbol), opts)}}, ","},
            {:doc_cons, {:doc_break, " ", :strict},
             {:doc_cons,
              {:doc_cons,
               {:doc_cons, "string:",
                {:doc_cons, " ", Inspect.inspect(Map.get(dict, :string), opts)}}, ","},
              {:doc_cons, {:doc_break, " ", :strict},
               {:doc_cons, "submatches:",
                {:doc_cons, " ", Inspect.inspect(Map.get(dict, :submatches), opts)}}}}}}}}, 2,
         :always}, {:doc_cons, {:doc_break, "", :strict}, "}"}}, :self}
    end
  end

  defimpl String.Chars do
    def to_string(%InterpreterTerms.SymbolMatch{string: str, symbol: symbol, submatches: sub}) do
      if sub == :none do
        String.Chars.to_string({:symbol, "::#{symbol}::#{str}"})
      else
        String.Chars.to_string(
          {:symbol, "::#{symbol}::#{str}", Enum.map(sub, &String.Chars.to_string/1)}
        )
      end
    end
  end
end

defmodule SymbolEmitter do
  defstruct [:generator, :symbol, :state, {:whitespace, ""}, :emit_submatches]

  def emit(alpha) do
    EbnfParser.Generator.emit(alpha)
  end

  # Generator protocol implementation dispatches to walk
  defimpl EbnfParser.Generator do
    def emit(
          %SymbolEmitter{
            generator: gen,
            symbol: sym,
            whitespace: whitespace,
            emit_submatches: emit_submatches
          } = emitter
        ) do
      case SymbolEmitter.emit(gen) do
        {:ok, gen, %Result{match_construct: construct, matched_string: str} = result} ->
          match_construct = %InterpreterTerms.SymbolMatch{
            symbol: sym,
            whitespace: whitespace,
            # TODO don't add whitespace for terminal symbols
            string: whitespace <> str
          }

          match_construct =
            if emit_submatches do
              %{match_construct | submatches: construct}
            else
              match_construct
            end

          {:ok, %{emitter | generator: gen},
           %{result | match_construct: [match_construct], matched_string: whitespace <> str}}

        _ ->
          {:fail}
      end
    end
  end
end
