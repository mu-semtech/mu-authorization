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
  def process_quads( %GraphSpec{ constraint: constraint } = graph_spec, info, quads, extra_quads ) do
    constraint
    |> Acl.GraphSpec.Constraint.Protocol.matching_quads( quads, extra_quads )
    |> IO.inspect( label: "Matching quads" )
    |> Enum.map( &alter_quad_graph(&1, graph_spec, info) )
    |> IO.inspect( label: "Renamed quads" )
    |> (fn (new_quads) -> quads ++ new_quads end).()
    |> IO.inspect( label: "All quads" )
  end

  defp alter_quad_graph( quad, %GraphSpec{} = graph_spec, info ) do
    new_graph =
      graph_spec
      |> matching_graph( info )
      |> wrap_graph

    %{ quad | graph: Iri.from_iri_string( new_graph ) }
  end

  defp wrap_graph( graph ) do
    "<" <> graph <> ">" # TODO: escape graph content! << might lead to accidental injection!
  end

  defp matching_graph( %GraphSpec{ graph: graph }, { _name, variables } = _auth_info ) do
    graph <> Enum.join( variables, "/" )
  end

  def process_query( %GraphSpec{} = graph_spec, info, query ) do
    new_graph = matching_graph( graph_spec, info )

    new_query =
      query
      |> Manipulators.SparqlQuery.add_from_graph( new_graph )

    { new_query, [info] }
  end


end
