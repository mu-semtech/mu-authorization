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
  def process_quads( %GraphSpec{ graph: graph, constraint: constraint } = graph_spec, info, quads, extra_quads ) do
    constraint
    |> Acl.GraphSpec.Constraint.Protocol.matching_quads( quads, extra_quads )
    |> IO.inspect( label: "Matching quads" )
    |> Enum.map( &alter_quad_graph(&1, graph_spec, info) )
    |> IO.inspect( label: "Renamed quads" )
    |> (fn (new_quads) -> quads ++ new_quads end).()
    |> IO.inspect( label: "All quads" )
  end

  defp alter_quad_graph( quad, %GraphSpec{ graph: graph }, { _name, variables } ) do
    new_graph = "<" <> graph <> Enum.join( variables, "/" ) <> ">" # TODO: escape graph content! << might lead to accidental injection!

    %{ quad | graph: Iri.from_iri_string( new_graph ) }
  end

end
