alias Updates.QueryAnalyzer.Iri, as: Iri
alias Updates.QueryAnalyzer.String, as: Str
alias Updates.QueryAnalyzer.Boolean, as: Bool
alias Updates.QueryAnalyzer.NumericLiteral, as: Number

defmodule Iri do
  defstruct [:iri, :real_name]

  def from_iri_string( iri, _options ) do
    new_iri = String.trim( iri, " " ) # TODO remove trimming when terminal symbols don't emit spaces anymore
    %Iri{ iri: new_iri, real_name: new_iri }
  end

  def from_prefix_string( prefixed_name, %{ prefixes: prefixes, default_graph: %Iri{ iri: default_graph } } ) do
    [ prefix, postfix ] =
      prefixed_name
      |> String.trim( " " ) # TODO remove trimming when terminal symbols don't emit spaces anymore
      |> String.split( ":", parts: 2 )

    base_uri =
      if prefix == "" do
        default_graph
        |> String.trim( " " ) # TODO remove trimming when terminal symbols don't emit spaces anymore
        |> String.slice( 1, String.length( default_graph ) - 2 )
      else
        %Iri{ iri: iri } = Map.get( prefixes, prefix )
        strip_iri_marks( iri )
      end

    full_iri = "<" <> base_uri <> postfix <> ">"
    %Iri{ iri: full_iri, real_name: prefixed_name }
  end

  def make_a do
    %Iri{ iri: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", real_name: "a" }
  end

  def is_a?( %Iri{ iri: iri } ) do
    iri == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  end

  defp strip_iri_marks( string ) do
    String.slice( string, 1, String.length( string ) - 2 )
  end
end

defmodule Bool do
  defstruct [:value]

  def from_string( value ) do
    bool = case String.downcase( value ) do
             'true' -> true
             'false' -> false
           end

    %Bool{ value: bool }
  end
  def from_boolean( boolean ) when is_boolean( boolean ) do
    %Bool{ value: boolean }
  end
end

defmodule Str do
  defstruct [:str, {:lang, false}, {:type, false}]

  def from_string( string ) do
    %Str{ str: string }
  end
  def from_langstring( string, language ) do
    %Str{ str: string, lang: language }
  end
  def from_typestring( string, type ) do
    %Str{ str: string, type: type }
  end
end

defmodule Number do
  defstruct [ :str ]

  def from_string( string ) do
    %Str{ str: string }
  end
end
