alias Generator.State, as: State
alias Generator.Result, as: Result
alias InterpreterTerms.Regex, as: RegexTerm
alias InterpreterTerms.Nothing, as: Nothing
alias InterpreterTerms.RegexEmitter, as: RegexEmitter

defmodule InterpreterTerms.RegexMatch do
  defstruct [:match, {:whitespace, ""}, {:external, %{}}]

  defimpl String.Chars do
    def to_string(%InterpreterTerms.RegexMatch{match: match}) do
      String.Chars.to_string({:match, match})
    end
  end
end

defmodule InterpreterTerms.Regex.Impl do
  defstruct [:regex]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.Regex.Impl{regex: regex}, _parsers, chars) do
      Regex.run(regex, to_string(chars)) |> generate_result(chars, regex)
    end

    defp generate_result(nil, chars, regex) do
      [%Generator.Error{errors: ["Did not match regex " <> regex.source], leftover: chars}]
    end

    defp generate_result([string | _matches], chars, _regex) do
      [
        %Result{
          leftover: Enum.drop(chars, String.length(string)),
          matched_string: string,
          match_construct: [%InterpreterTerms.RegexMatch{match: string}]
        }
      ]
    end
  end
end

defmodule InterpreterTerms.Regex do
  defstruct regex: ""

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%InterpreterTerms.Regex{regex: regex}) do
      %InterpreterTerms.Regex.Impl{
        regex: regex
      }
    end
  end
end
