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

defmodule NotBracket do
  alias Generator.State, as: State
  alias Generator.Result, as: Result
  alias InterpreterTerms.Bracket, as: Bracket

  defstruct [:options, {:state, %State{}}]

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%NotBracket{options: options}) do
      parse_f = fn x -> options |> Enum.any?(&match_option(&1, x)) |> Kernel.not end

      error_f = fn x, chars ->
        opts = options |> Enum.map(&error_options/1) |> List.to_string()
        %Generator.Error{errors: ["'" <> x <> "' not in [" <> opts <> "]"], leftover: chars}
      end

      InterpreterTerms.Function.single_char_match(parse_f, error_f)
    end

    # TODO: remove duplicate code from bracket!

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
