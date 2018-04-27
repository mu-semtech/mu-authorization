alias Generator.State, as: State
alias Generator.Result, as: Result
alias InterpreterTerms.NotBracket, as: NotBracket
alias InterpreterTerms.Bracket, as: Bracket

defmodule NotBracket do
  defstruct [:options, {:state, %State{}}]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %NotBracket{} = bracket ) do
      bracket
    end
  end

  defimpl EbnfParser.Generator do
    def emit( %NotBracket{} = bracket ) do
      NotBracket.check( bracket )
    end
  end

  def check( %NotBracket{ options: options, state: state } = not_bracket) do
    # Inverse solution of bracket
    solution =
      %Bracket{ options: options, state: state }
      |> EbnfParser.GeneratorProtocol.make_generator
      |> EbnfParser.Generator.emit

    case solution do
      { :ok, _, _ } -> {:fail}
      _ -> emit_result( not_bracket )
    end
  end

  defp emit_result( %NotBracket{ state: %State{ chars: [ char | chars ] } } ) do
    { :ok,
      %InterpreterTerms.Nothing{},
      %Result{
        leftover: chars,
        matched_string: char
      }
    }    
  end

end
