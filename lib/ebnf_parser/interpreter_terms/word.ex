alias Generator.State, as: State
alias Generator.Result, as: Result
alias InterpreterTerms.Word, as: Word
alias InterpreterTerms.Nothing, as: Nothing

import Generator.State, only: [ drop_spaces: 1, is_terminal: 1 ]

defmodule InterpreterTerms.Word do
  defstruct [word: "", state: %State{}]

  # Nothing special to build
  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %InterpreterTerms.Word{} = word_term ) do
      word_term
    end
  end

  # The generator drops spaces and tries to match
  defimpl EbnfParser.Generator do
    def emit( %Word{ word: word, state: state } ) do
      # Drop spaces if allowed
      { state, whitespace } = if is_terminal( state ) do
        { state, "" }
      else
        Generator.State.split_off_whitespace( state )
      end

      # Check if we start with the right word
      %State{ chars: chars } = state
      if word == to_string( Enum.take( chars, String.length( word ) ) ) do
        result = %Result{
          leftover: Enum.drop( chars, String.length( word ) ),
          matched_string: whitespace <> word
        }
        { :ok, %Nothing{}, result }
      else
        { :fail }
      end
    end
  end
end
