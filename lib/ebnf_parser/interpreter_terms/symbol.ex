defmodule InterpreterTerms.SymbolMatch do
  defstruct [:string, :symbol, {:submatches, :none}, {:whitespace, ""}, {:external, %{}}]

  defimpl Inspect, for: InterpreterTerms.SymbolMatch do
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

  defimpl String.Chars, for: InterpreterTerms.SymbolMatch do
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

defmodule InterpreterTerms.Symbol.Impl do
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
             matched_string: matched_string,
             errors: errors
           } = res,
           symbol,
           whitespace,
           _is_term
         ) do
      %{res | errors: [symbol | errors], matched_string: whitespace <> matched_string}
    end
  end
end

defmodule InterpreterTerms.Symbol do
  alias Generator.State, as: State

  defstruct [:symbol]

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
