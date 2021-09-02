defmodule InterpreterTerms.Function do
  alias Generator.Result, as: Result

  @type parse_f :: ([String.grapheme()] -> EbnfParser.ParseProtocol.response())
  @type t :: %__MODULE__{parse_f: parse_f()}
  defstruct [:parse_f]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Function{parse_f: parse_f}, _parsers, chars) do
      parse_f.(chars)
    end
  end

  defp empty_fail(char) do
    {:failed, {:function, "'" <> char <> "' did not match function"}}
  end

  @spec single_char_match(
          (String.grapheme() -> boolean()),
          (String.grapheme() -> {:failed, any()})
        ) :: InterpreterTerms.Function.t()
  def single_char_match(match_f, fail_f \\ &empty_fail/1) do
    inner = fn [char | chars] ->
      if match_f.(char) do
        [
          %Result{
            leftover: chars,
            matched_string: char,
            match_construct: [%InterpreterTerms.BracketResult{character: char}]
          }
        ]
      else
        [fail_f.(char)]
      end
    end

    %InterpreterTerms.Function{
      parse_f: inner
    }
  end
end
