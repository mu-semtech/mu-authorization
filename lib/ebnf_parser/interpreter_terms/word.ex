alias Generator.State, as: State
alias Generator.Result, as: Result
alias InterpreterTerms.Word, as: Word
alias InterpreterTerms.Nothing, as: Nothing

import Generator.State, only: [is_terminal: 1]

defmodule InterpreterTerms.WordMatch do
  defstruct [:word, {:whitespace, ""}, {:external, %{}}]

  @type t :: %InterpreterTerms.WordMatch{}

  defimpl String.Chars do
    def to_string(%InterpreterTerms.WordMatch{word: word}) do
      String.Chars.to_string({:word, word})
    end
  end
end

defmodule InterpreterTerms.Word do
  defstruct word: "", state: %State{}

  # Nothing special to build
  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%InterpreterTerms.Word{} = word_term) do
      word_term
    end
  end

  # The generator drops spaces and tries to match
  defimpl EbnfParser.Generator do
    def emit(%Word{word: word, state: state}) do
      # Drop spaces if allowed
      {state, whitespace} =
        if is_terminal(state) do
          {state, ""}
        else
          Generator.State.split_off_whitespace(state)
        end

      # Check if we start with the right word
      %State{chars: chars} = state

      # we upcase both parts, because there's the 'a' case which is to be transformed as lowercase...
      if String.upcase(word) == String.upcase(to_string(Enum.take(chars, String.length(word)))) do
        result = %Result{
          # We don't drop whitespace, split_off_whitespace has done
          # this for us.
          leftover: Enum.drop(chars, String.length(word)),
          matched_string: whitespace <> word,
          match_construct: [%InterpreterTerms.WordMatch{word: word, whitespace: whitespace}]
        }

        {:ok, %Nothing{}, result}
      else
        {:fail}
      end
    end
  end
end
