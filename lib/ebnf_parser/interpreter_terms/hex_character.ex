alias InterpreterTerms.HexCharacter, as: HexCharacter

defmodule InterpreterTerms.HexCharacterResult do
  defstruct [:character, {:external, %{}}]

  defimpl String.Chars do
    def to_string(%InterpreterTerms.HexCharacterResult{character: char}) do
      String.Chars.to_string({:"#", char})
    end
  end
end

defmodule HexCharacter do
  alias Generator.State, as: State
  alias Generator.Result, as: Result
  defstruct [:number, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%HexCharacter{} = hex_char) do
      hex_char
    end
  end

  defimpl EbnfParser.Generator do
    def emit(%HexCharacter{state: %State{chars: []}}) do
      {:fail}
    end

    def emit(%HexCharacter{number: number, state: %State{chars: [char | chars]}}) do
      if char == <<number::utf8>> do
        {:ok, %InterpreterTerms.Nothing{},
         %Result{
           leftover: chars,
           matched_string: char,
           match_construct: [%InterpreterTerms.HexCharacterResult{character: char}]
         }}
      else
        {:fail}
      end
    end
  end

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%HexCharacter{} = hex) do
      hex
    end
  end

  defimpl EbnfParser.ParseProtocol do
    def parse(%HexCharacter{number: number}, _parsers, [char | chars]) do
      test = <<number::utf8>>

      if char == test do
        [
          %Result{
            leftover: chars,
            matched_string: char,
            match_construct: [%InterpreterTerms.HexCharacterResult{character: char}]
          }
        ]
      else
        [
          %Generator.Error{
            errors: [{:Hex, "Could not match '" <> test <> "' with '" <> char <> "'"}],
            leftover: chars
          }
        ]
      end
    end
  end
end
