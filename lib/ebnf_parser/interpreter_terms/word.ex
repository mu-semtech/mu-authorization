defmodule InterpreterTerms.WordMatch do
  defstruct [:word, {:whitespace, ""}, {:external, %{}}]

  @type t :: %InterpreterTerms.WordMatch{
          word: String.t(),
          whitespace: String.t(),
          external: map()
        }

  defimpl String.Chars do
    def to_string(%InterpreterTerms.WordMatch{word: word}) do
      String.Chars.to_string({:word, word})
    end
  end
end

defmodule InterpreterTerms.Word.Impl do
  alias Generator.Result, as: Result
  alias InterpreterTerms.Nothing, as: Nothing
  alias Generator.State, as: State

  defstruct word: ""

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Word.Impl{word: word}, _parsers, chars) do
      {new_chars, whitespace} = State.cut_whitespace(chars)

      test_str = new_chars |> Enum.take(String.length(word)) |> to_string

      if word |> String.upcase() == test_str |> String.upcase() do
        result = %Result{
          # We don't drop whitespace, split_off_whitespace has done
          # this for us.
          leftover: Enum.drop(new_chars, String.length(word)),
          matched_string: whitespace <> word,
          match_construct: [%InterpreterTerms.WordMatch{word: word, whitespace: whitespace}]
        }

        [result]
      else
        [
          %Generator.Error{
            errors: ["Could not match '" <> word <> "' with '" <> test_str <> "'"],
            leftover: chars
          }
        ]
      end
    end
  end
end

defmodule InterpreterTerms.Word do
  alias InterpreterTerms.Word, as: Word
  alias Generator.Result, as: Result
  alias InterpreterTerms.Nothing, as: Nothing

  defstruct word: ""

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Word{word: word}) do
      %InterpreterTerms.Word.Impl{word: word}
    end
  end
end
