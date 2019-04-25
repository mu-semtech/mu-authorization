alias Generator.State, as: State
alias Generator.Result, as: Result
alias InterpreterTerms.Regex, as: RegexTerm
alias InterpreterTerms.Nothing, as: Nothing
alias InterpreterTerms.RegexEmitter, as: RegexEmitter

defmodule InterpreterTerms.RegexMatch do
  defstruct [:match, {:whitespace, ""}, { :external, %{} }]

  defimpl String.Chars do
    def to_string( %InterpreterTerms.RegexMatch{ match: match } ) do
      { :match, match }
    end
  end
end

defmodule RegexEmitter do
  defstruct [:state, :known_matches]

  defimpl EbnfParser.Generator do
    def emit( %RegexEmitter{ known_matches: [] } ) do
      # IO.inspect( [], label: "No known matches" )
      { :fail }
    end

    def emit( %RegexEmitter{ state: state, known_matches: [string] } ) do
      # IO.inspect( [string], label: "known matches" )
      { :ok, %Nothing{}, RegexEmitter.generate_result( state, string ) }
    end

    def emit( %RegexEmitter{ state: state, known_matches: [match|rest] } = emitter ) do
      # IO.inspect( [match|rest], label: "Known matches" )
      # IO.inspect( match, label: "Current match" )

      { :ok, %{ emitter | known_matches: rest }, RegexEmitter.generate_result( state, match ) }
    end
  end

  def generate_result( state, string ) do
    %State{ chars: chars } = state

    %Result{
      leftover: Enum.drop( chars, String.length( string ) ),
      matched_string: string,
      match_construct: [%InterpreterTerms.RegexMatch{ match: string }]
    }
  end

end

defmodule InterpreterTerms.Regex do
  defstruct [regex: "", state: %State{}, known_matches: []]

  defimpl EbnfParser.GeneratorProtocol do
    def make_generator( %RegexTerm{ regex: regex, state: state } = _regex_term ) do
      # regex
      # |> IO.inspect( label: "Received regex" )

      # Get the charactors from our state
      char_string =
        state
        |> Generator.State.chars_as_string
        # |> IO.inspect( label: "Character string to operate on" )


      # TODO be smart and use Regex.run instead
      matching_strings =
        regex
        |> Regex.scan( char_string, [capture: :first] )
        |> ( fn (results) -> results || [] end ).()
        |> Enum.map( &(Enum.at(&1, 0)) )
        # |> IO.inspect( label: "Matching strings" )

      %RegexEmitter{ state: state, known_matches: matching_strings }
    end
  end

end
