defmodule Parser do
  use EbnfParser.Sparql, rule_name: :Sparql

  @moduledoc """
  Entrypoint to parse SPARQL queries and the W3C EBNF syntax.
  """
  @type syntax :: %{optional(atom) => any}
  @type unparsed_query :: String.t()
  @type query :: %InterpreterTerms.SymbolMatch{} | %InterpreterTerms.WordMatch{}

  @spec sparql_syntax() :: syntax
  def sparql_syntax do
    EbnfParser.Sparql.syntax()
  end

  @spec sparql_parsers() :: [EbnfParser.ParserProtocol.t()]
  def sparql_parsers do
    EbnfParser.Sparql.parsers()
  end
end
