defmodule SparqlClient.QueryResponse do
  @moduledoc "Parsing of query responses for more structured processing with type checking"

  alias Updates.QueryAnalyzer.Iri, as: Iri
  alias Updates.QueryAnalyzer.String, as: Str
  alias Updates.QueryAnalyzer.Boolean, as: Bool
  alias Updates.QueryAnalyzer.NumericLiteral, as: Number

  defstruct head: %{}, results: %{}

  use Accessible

  @type t :: %SparqlClient.QueryResponse{head: head, results: results}
  @type head :: %{optional(:vars) => [String.t()]}
  @type results :: %{results: %{bindings: bindings}}
  @type bindings :: [single_binding]
  @type single_binding :: %{String.t() => single_binding_value}

  @type single_binding_value ::
          iri
          | untyped_literal
          | language_tagged_literal
          | datatype_tagged_literal
          | bnode

  @type binding_type :: :uri | :literal | :bnode
  @type binding_value :: String.t()
  @type binding_lang :: String.t()
  @type binding_datatype :: String.t()
  @type binding_bnode_value :: String.t()

  @type iri :: %{type: :uri, value: binding_value}
  @type untyped_literal :: %{type: :literal, value: binding_value}
  @type language_tagged_literal :: %{
          type: :literal,
          value: binding_value,
          lang: binding_lang
        }
  @type datatype_tagged_literal :: %{
          type: :literal,
          value: binding_value,
          datatype: binding_datatype
        }
  @type bnode :: %{type: :bnode, value: binding_bnode_value}

  @doc """
  Converts a parsed query response into a QueryResponse instance.
  """
  @spec from_parsed_response(SparqlClient.parsed_query_response()) :: t
  def from_parsed_response(response) do
    %SparqlClient.QueryResponse{
      head: parse_head(Map.get(response, "head")),
      results: parse_results(Map.get(response, "results"))
    }
  end

  @spec parse_head(map()) :: head
  defp parse_head(%{"vars" => vars}), do: %{vars: vars}
  defp parse_head(_), do: %{}

  @spec parse_results(map()) :: results
  defp parse_results(%{"bindings" => bindings}) do
    %{bindings: Enum.map(bindings, &parse_single_binding/1)}
  end

  @spec parse_single_binding(map()) :: single_binding
  defp parse_single_binding(map) do
    Map.keys(map)
    |> Enum.map(fn key ->
      {key, parse_single_binding_value(Map.get(map, key))}
    end)
    |> Enum.into(%{})
  end

  @spec parse_single_binding_value(map()) :: single_binding_value
  defp parse_single_binding_value(%{"type" => "bnode", "value" => value}) do
    %{type: :bnode, value: value}
  end

  defp parse_single_binding_value(%{"type" => "literal", "value" => value, "datatype" => datatype}) do
    %{type: :literal, value: value, datatype: datatype}
  end

  defp parse_single_binding_value(%{"type" => "literal", "value" => value, "xml:lang" => lang}) do
    %{type: :literal, value: value, lang: lang}
  end

  defp parse_single_binding_value(%{"type" => "literal", "value" => value}) do
    %{type: :literal, value: value}
  end

  defp parse_single_binding_value(%{"type" => "uri", "value" => value}) do
    %{type: :uri, value: value}
  end

  # Iri.t() | Var.t() | Bool.t() | Str.t() | Number.t()
  @spec primitive_value( single_binding_value ) :: Updates.QueryAnalyzer.value
  def primitive_value(%{type: :uri, value: value}) do
    Iri.from_iri_string( Iri.wrap_iri_string( value ) )
  end

  def primitive_value(%{type: :literal, value: value, lang: lang}) do
    Str.from_langstring(value, lang)
  end

  def primitive_value(%{type: :literal, value: value, datatype: datatype}) do
    # TODO: support other things than numbers
    Number.from_string("\"\"\"#{value}\"\"\"^<#{datatype}>")
  end
end
