alias Updates.QueryAnalyzer.Iri, as: Iri
alias Updates.QueryAnalyzer.String, as: Str
alias Updates.QueryAnalyzer.Boolean, as: Bool
alias Updates.QueryAnalyzer.NumericLiteral, as: Number
alias Updates.QueryAnalyzer.Variable, as: Var

alias InterpreterTerms.SymbolMatch, as: Sym
alias InterpreterTerms.WordMatch, as: Word

defprotocol Updates.QueryAnalyzer.P do
  def to_solution_sym(element)

  def to_sparql_result_value(element)
end

defmodule Iri do
  @type t :: %Iri{iri: String.t(), real_name: String.t()}

  defstruct [:iri, :real_name]

  def from_iri_string(iri, _options \\ []) do
    # TODO remove trimming when terminal symbols don't emit spaces anymore
    new_iri = String.trim(iri, " ")
    %Iri{iri: new_iri, real_name: new_iri}
  end

  def from_prefix_string(prefixed_name, options) do
    prefixes = Map.get(options, :prefixes, %{})

    [prefix, postfix] =
      prefixed_name
      # TODO remove trimming when terminal symbols don't emit spaces anymore
      |> String.trim(" ")
      |> String.split(":", parts: 2)

    base_uri =
      cond do
        # no prefix was supplied
        prefix == "" ->
          %Iri{iri: default_graph} = Map.get(options, :default_graph)

          default_graph
          # TODO remove trimming when terminal symbols don't emit spaces anymore
          |> String.trim(" ")
          |> String.slice(1, String.length(default_graph) - 2)

        # the supplied prefix is in our options
        Map.has_key?(prefixes, prefix) ->
          %Iri{iri: iri} = Map.get(prefixes, prefix)
          strip_iri_marks(iri)

        # the supplied prefix is a default prefix
        true ->
          %Iri{iri: iri} = Map.get(default_prefixes(), prefix)
          strip_iri_marks(iri)
      end

    full_iri = wrap_iri_string(base_uri <> postfix)
    %Iri{iri: full_iri, real_name: prefixed_name}
  end

  @doc """

  A best effort to convert a symbol containing an Iri into an Iri object

  """
  def from_symbol(a) do
    from_symbol(a, %{})
  end

  def from_symbol(%Word{word: "a"}, _options) do
    Iri.make_a()
  end

  def from_symbol(%Sym{symbol: :iri, submatches: [%Sym{symbol: :IRIREF, string: str}]}, _options) do
    Iri.from_iri_string(str)
  end

  def from_symbol(
        %Sym{symbol: :iri, submatches: [%Sym{symbol: :PrefixedName, string: str}]},
        options
      ) do
    Iri.from_prefix_string(str, options)
  end

  def wrap_iri_string(iri_string) do
    "<" <> iri_string <> ">"
  end

  def unwrap_iri_string(iri_string) do
    String.slice(iri_string, 1, String.length(iri_string) - 2)
  end

  def make_a do
    %Iri{iri: "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>", real_name: "a"}
  end

  def is_a?(%Iri{iri: iri}) do
    iri == "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>"
  end

  def same?(%Iri{iri: iri}, %Iri{iri: iri}) do
    true
  end

  def same?(_, _) do
    false
  end

  @doc """
  Map containing a set of default prefixes which may be assumed to
  have been defined even though they haven't been specified
  explicitly.
  """
  def default_prefixes do
    %{}
    |> Map.put("xsd", Iri.from_iri_string("<http://www.w3.org/2001/XMLSchema#>"))
  end

  defp strip_iri_marks(string) do
    String.slice(string, 1, String.length(string) - 2)
  end

  defimpl Updates.QueryAnalyzer.P do
    def to_solution_sym(%Iri{iri: full_name}) do
      # TODO: Emit values the way we received them
      %InterpreterTerms.SymbolMatch{
        symbol: :iri,
        submatches: [
          %InterpreterTerms.SymbolMatch{symbol: :IRIREF, string: full_name, submatches: :none}
        ]
      }
    end

    def to_sparql_result_value(%Iri{iri: full_iri}) do
      %{type: "uri", value: Iri.unwrap_iri_string(full_iri)}
    end
  end
end

defmodule Var do
  defstruct [:full_name]

  @type t :: %Var{full_name: String.t()}

  def from_string(value) do
    %Var{full_name: value}
  end

  def is_var(%Var{}) do
    true
  end

  def is_var(_) do
    false
  end

  @doc """
  Returns the name of the variable without its prefix.

      iex> Updates.QueryAnalyzer.Variable.pure_name( %Updates.QueryAnalyzer.Variable{ full_name: "?foo" } )
      > "foo"
  """
  def pure_name(%Var{full_name: full_name}) do
    {_, pure_name} = String.next_grapheme(full_name)
    pure_name
  end

  defimpl Updates.QueryAnalyzer.P do
    def to_solution_sym(%Var{} = var) do
      Var.to_solution_sym(var)
    end

    def to_sparql_result_value(%Var{}) do
      raise "Cannot convert Variable to SPARQL1.1 result"
    end
  end

  def to_solution_sym(%Var{full_name: full_name}) do
    symbol =
      case full_name do
        <<"?", _::binary>> -> :VAR1
        <<"$", _::binary>> -> :VAR2
      end

    %InterpreterTerms.SymbolMatch{
      symbol: :Var,
      submatches: [
        %InterpreterTerms.SymbolMatch{
          symbol: symbol,
          string: full_name,
          submatches: :none
        }
      ]
    }
  end
end

defmodule Bool do
  defstruct [:value]

  @type t :: %Bool{value: boolean}

  def from_string(value) do
    bool =
      case String.downcase(value) do
        "true" -> true
        "false" -> false
      end

    %Bool{value: bool}
  end

  def from_boolean(boolean) when is_boolean(boolean) do
    %Bool{value: boolean}
  end

  defimpl Updates.QueryAnalyzer.P do
    def to_solution_sym(%Bool{value: value}) do
      word =
        if value do
          "true"
        else
          "false"
        end

      %InterpreterTerms.SymbolMatch{
        symbol: :RDFLiteral,
        submatches: [
          %InterpreterTerms.SymbolMatch{
            symbol: :BooleanLiteral,
            submatches: [%InterpreterTerms.WordMatch{word: word}]
          }
        ]
      }
    end

    def to_sparql_result_value(%Bool{value: value}) do
      value_string =
        case value do
          true -> "true"
          false -> "false"
        end

      %{
        type: "literal",
        value: value_string,
        datatype: "http://www.w3.org/2001/XMLSchema#boolean"
      }
    end
  end
end

defmodule Str do
  defstruct [:str, {:lang, false}, {:type, false}]

  @type t ::
          %Str{str: String.t(), lang: false, type: false}
          | %Str{str: String.t(), lang: true, type: false}
          | %Str{str: String.t(), lang: false, type: true}

  def from_string(string) do
    %Str{str: string}
  end

  def from_langstring(string, language) do
    %Str{str: string, lang: language}
  end

  def from_typestring(string, type) do
    %Str{str: string, type: type}
  end

  defimpl Updates.QueryAnalyzer.P do
    def to_solution_sym(%Str{str: string, lang: lang, type: type} = str) do
      # TODO: handle escaping of strings correctly, depending where
      # they came from.  This requires changes in from_string
      # (optional argument), and Updates.QueryAnalyzer#primitive_value_from_binding
      # and Updates.QueryAnalyzer#primitive_value.  We found no other
      # uses of this at the time of writing.
      triple_escaped_string = string

      case str do
        %Str{lang: false, type: false} ->
          # it is a simple string
          %InterpreterTerms.SymbolMatch{
            symbol: :RDFLiteral,
            submatches: [
              %InterpreterTerms.SymbolMatch{
                symbol: :String,
                submatches: [
                  %InterpreterTerms.SymbolMatch{
                    symbol: :STRING_LITERAL_LONG_2,
                    string: triple_escaped_string,
                    submatches: :none
                  }
                ]
              }
            ]
          }

        %Str{lang: false} ->
          # it is a typed string
          %InterpreterTerms.SymbolMatch{
            symbol: :RDFLiteral,
            submatches: [
              %InterpreterTerms.SymbolMatch{
                symbol: :String,
                submatches: [
                  %InterpreterTerms.SymbolMatch{
                    symbol: :STRING_LITERAL_LONG_2,
                    string: triple_escaped_string,
                    submatches: :none
                  }
                ]
              },
              %InterpreterTerms.WordMatch{word: "^^"},
              Updates.QueryAnalyzer.P.to_solution_sym(type)
            ]
          }

        %Str{type: false} ->
          # it is a language typed string
          %InterpreterTerms.SymbolMatch{
            symbol: :RDFLiteral,
            submatches: [
              %InterpreterTerms.SymbolMatch{
                symbol: :String,
                submatches: [
                  %InterpreterTerms.SymbolMatch{
                    symbol: :STRING_LITERAL_LONG_2,
                    string: triple_escaped_string,
                    submatches: :none
                  }
                ]
              },
              %InterpreterTerms.SymbolMatch{
                symbol: :LANGTAG,
                string: "@" <> lang,
                submatches: :none
              }
            ]
          }
      end
    end

    def to_sparql_result_value(%Str{str: str, lang: false, type: false}) do
      %{type: "literal", value: unescape_sparql_string(str)}
    end

    def to_sparql_result_value(%Str{str: str, lang: lang, type: false}) do
      # TODO discuss whether it's really ok to write xml:lang here,
      # instead of writing out the xml namespace.
      %{type: "literal", value: unescape_sparql_string(str), "xml:lang": lang}
    end

    def to_sparql_result_value(%Str{str: str, lang: false, type: %Iri{iri: type_iri}}) do
      type = Iri.unwrap_iri_string(type_iri)
      %{type: "literal", value: unescape_sparql_string(str), datatype: type}
    end

    defp unescape_sparql_string(str) do
      if String.starts_with?(str, "\"\"\"") do
        str
        |> String.replace_prefix("\"\"\"", "")
        |> String.replace_suffix("\"\"\"", "")
        |> String.replace("\\\"", "\"")
      else
        str
        |> String.replace_prefix("\"", "")
        |> String.replace_suffix("\"", "")
        |> String.replace("\\\"", "\"")
      end
    end
  end
end

defmodule Number do
  defstruct [:str]

  def from_string(string) do
    %Str{str: string}
  end

  defimpl Updates.QueryAnalyzer.P do
    def to_solution_sym(%Number{str: str}) do
      # TODO this does not necessarily emit the correct structure, yet
      # it will yield the correct SPARQL query.

      %InterpreterTerms.SymbolMatch{
        symbol: :RDFLiteral,
        submatches: [
          %InterpreterTerms.SymbolMatch{
            symbol: :NumericLiteral,
            submatches: [
              %InterpreterTerms.SymbolMatch{
                symbol: :NumericLiteralUnsigned,
                submatches: [
                  %InterpreterTerms.SymbolMatch{symbol: :DECIMAL, string: str, submatches: :none}
                ]
              }
            ]
          }
        ]
      }
    end

    def to_sparql_result_value(%Number{str: str}) do
      # We do not know the type of the number, hence we output the
      # string as a decimal.  We should verify whether or not there
      # are formatting rules about this and/or whether we can import
      # the specific type from the definition.
      %{type: "literal", value: str, datatype: "http://www.w3.org/2001/XMLSchema#decimal"}
    end
  end
end
