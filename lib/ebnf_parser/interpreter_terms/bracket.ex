alias InterpreterTerms.Bracket, as: Bracket

defmodule InterpreterTerms.BracketResult do
  alias Generator.State, as: State
  alias Generator.Result, as: Result

  defstruct [:character]

  defimpl String.Chars do
    def to_string(%InterpreterTerms.BracketResult{character: char}) do
      String.Chars.to_string({:"#", char})
    end
  end
end

defmodule Bracket do
  alias Generator.State, as: State
  alias Generator.Result, as: Result

  defstruct [:options, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator(%Bracket{} = bracket) do
      bracket
    end
  end

  defimpl EbnfParser.ParserProtocol do
    def make_parser(%Bracket{options: options}) do
      parse_f = fn x -> options |> Enum.any?(&match_option(&1, x)) end

      error_f = fn x, chars ->
        opts = options |> Enum.map(&error_options/1) |> List.to_string()
        %Generator.Error{errors: ["'" <> x <> "' not in [" <> opts <> "]"], leftover: chars}
      end

      InterpreterTerms.Function.single_char_match(parse_f, error_f)
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

  defimpl EbnfParser.Generator do
    def emit(%Bracket{} = bracket) do
      Bracket.check(bracket)
    end
  end

  def check(%Bracket{options: []}) do
    {:fail}
  end

  def check(
        %Bracket{
          options: [{:range, [start_char, end_char]} | _],
          state: %State{chars: [char | _]}
        } = bracket
      ) do
    if char_for_code(start_char) <= char && char <= char_for_code(end_char) do
      bracket
      |> emit_result
    else
      bracket
      |> try_next_option
    end
  end

  def check(%Bracket{options: [char_obj | _], state: %State{chars: [char | _]}} = bracket) do
    if char == char_for_code(char_obj) do
      bracket
      |> emit_result
    else
      bracket
      |> try_next_option
    end
  end

  def check(%Bracket{state: %State{chars: []}}) do
    {:fail}
  end

  defp char_for_code({:character, char}) do
    char
  end

  defp char_for_code({:hex_character, codepoint}) do
    <<codepoint::utf8>>
  end

  defp emit_result(%Bracket{state: %State{chars: [char | chars]}}) do
    {:ok, %InterpreterTerms.Nothing{},
     %Result{
       leftover: chars,
       matched_string: char,
       match_construct: [%InterpreterTerms.BracketResult{character: char}]
     }}
  end

  defp try_next_option(%Bracket{options: [_ | rest]} = bracket) do
    bracket
    |> Map.put(:options, rest)
    |> check
  end
end
