alias InterpreterTerms.NotBracket, as: NotBracket

defmodule InterpreterTerms.NotBracketResult do
  alias Generator.State, as: State
  alias Generator.Result, as: Result
  alias InterpreterTerms.Bracket, as: Bracket

  defstruct [:character]

  defimpl String.Chars do
    def to_string(%InterpreterTerms.NotBracketResult{character: char}) do
      String.Chars.to_string({:"#", char})
    end
  end
end

defmodule InterpreterTerms.NotBracket.Impl do
  defstruct [:options]

  defimpl EbnfParser.ParseProtocol do
    def parse(%InterpreterTerms.NotBracket.Impl{options: options}, _parsers, chars) do
      {new_chars, whitespace} = Generator.State.cut_whitespace(chars)

      case new_chars do
        [char | chars] ->
          if options |> Enum.any?(&match_option(&1, char)) |> Kernel.not() do
            [
              %Generator.Result{
                leftover: chars,
                matched_string: whitespace <> char,
                match_construct: [%InterpreterTerms.NotBracketResult{character: char}]
              }
            ]
          else
            opts = options |> Enum.map(&error_options/1) |> List.to_string()

            [
              %Generator.Error{
                errors: ["'" <> char <> "' not in [" <> opts <> "]"],
                leftover: chars
              }
            ]
          end

        [] ->
          opts = options |> Enum.map(&error_options/1) |> List.to_string()

          [
            %Generator.Error{
              errors: ["Can't match empty string with [" <> opts <> "]"],
              leftover: chars
            }
          ]
      end
    end

    defp match_option({:range, [start_char, end_char]}, char) do
      char_for_code(start_char) <= char && char <= char_for_code(end_char)
    end

    defp match_option(char_obj, char) do
      char_for_code(char_obj) == char
    end

    defp error_options({:range, [start_char, end_char]}) do
      char_for_code(start_char) <> "-" <> char_for_code(end_char)
    end

    defp error_options(char_obj) do
      char_for_code(char_obj)
    end

    # TODO remove duplicate code
    defp char_for_code({:character, char}) do
      char
    end

    defp char_for_code({:hex_character, codepoint}) do
      <<codepoint::utf8>>
    end
  end
end

defmodule NotBracket do
  alias Generator.State, as: State
  alias Generator.Result, as: Result
  alias InterpreterTerms.Bracket, as: Bracket

  defstruct [:options, {:state, %State{}}]

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%NotBracket{options: options}) do
      %InterpreterTerms.NotBracket.Impl{options: options}
    end
  end

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%NotBracket{} = bracket) do
      bracket
    end
  end

  defimpl EbnfParser.Generator do
    def emit(%NotBracket{} = bracket) do
      NotBracket.check(bracket)
    end
  end

  def check(%NotBracket{options: options, state: state} = not_bracket) do
    # Inverse solution of bracket
    solution =
      %Bracket{options: options, state: state}
      |> EbnfParser.GeneratorProtocol.make_generator()
      |> EbnfParser.Generator.emit()

    case solution do
      {:ok, _, _} -> {:fail}
      _ -> emit_result(not_bracket)
    end
  end

  defp emit_result(%NotBracket{state: %State{chars: [char | chars]}}) do
    {:ok, %InterpreterTerms.Nothing{},
     %Result{
       leftover: chars,
       matched_string: char,
       match_construct: [%InterpreterTerms.NotBracketResult{character: char}]
     }}
  end
end
