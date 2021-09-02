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

  defp empty_fail(char, chars) do
    %Generator.Error{
      errors: [{:function, "'" <> char <> "' did not match function"}],
      leftover: chars
    }
  end

  @spec single_char_match(
          (String.grapheme() -> boolean()),
          (String.grapheme(), [String.grapheme()] -> Generator.Error.t())
        ) :: InterpreterTerms.Function.t()
  def single_char_match(match_f, fail_f \\ &empty_fail/2) do
    %InterpreterTerms.Function{
      parse_f: &do_single_char_match(&1, match_f, fail_f)
    }
  end

  defp do_single_char_match(chars, match_f, fail_f) do
    {new_chars, whitespace} = Generator.State.cut_whitespace(chars)

    case new_chars do
      [char | chars] ->
        if match_f.(char) do
          [
            %Result{
              leftover: chars,
              matched_string: whitespace <> char,
              match_construct: [%InterpreterTerms.BracketResult{character: char}]
            }
          ]
        else
          [fail_f.(char, chars)]
        end

      [] ->
        [fail_f.("", chars)]
    end
  end
end
