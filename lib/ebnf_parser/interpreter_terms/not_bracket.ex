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
