alias Updates.QueryAnalyzer.Iri, as: Iri
alias Acl.GraphSpec, as: GraphSpec

defmodule Acl.GraphSpec do
  defstruct [ :graph, :constraint ]

  @moduledoc """
  A GraphSpec indicates which triples should be stored in a specific
  graph.
  """

  @doc """
  Processes the currently available quads.  First collecting the quads based on the Constraint, then moving the new quads into the new graph.
  """
  def process_quads( %GraphSpec{ graph: graph, constraint: constraint }, quads, extra_quads ) do
    constraint
    |> Acl.GraphSpec.Constraint.Protocol.matching_quads( quads, extra_quads )
    |> IO.inspect( label: "Matching quads" )
    |> Enum.map( fn (quad) -> %{ quad | graph: Iri.from_iri_string( "<" <> graph <> ">" ) } end )
    |> IO.inspect( label: "Renamed quads" )
    |> (fn (new_quads) -> quads ++ new_quads end).()
    |> IO.inspect( label: "All quads" )
  end
end
