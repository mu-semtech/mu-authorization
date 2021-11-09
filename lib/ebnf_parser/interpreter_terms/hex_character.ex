alias InterpreterTerms.HexCharacter, as: HexCharacter

defmodule InterpreterTerms.HexCharacterResult do
  defstruct [:character, {:external, %{}}]

  defimpl String.Chars, for: InterpreterTerms.HexCharacterResult do
    def to_string(%InterpreterTerms.HexCharacterResult{character: char}) do
      String.Chars.to_string({:"#", char})
    end
  end
end

defmodule HexCharacter do
  alias Generator.Result, as: Result
  defstruct [:number]

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
