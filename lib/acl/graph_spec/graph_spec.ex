defmodule Acl.GraphSpec do
  alias Updates.QueryAnalyzer.Iri, as: Iri
  alias Acl.GraphSpec, as: GraphSpec
  alias Acl.GraphSpec.Constraint.Resource, as: ResourceConstraint

  require Logger
  require ALog

  @type t :: %GraphSpec{
          graph: String.t(),
          constraint: ResourceConstraint.t(),
          usage: [Acl.GroupSpec.useage_method()] | nil
        }

  defstruct [:graph, :constraint, :usage]

  @moduledoc """
  A GraphSpec indicates which triples should be stored in a specific
  graph.
  """

  @doc """
  Processes the currently available quads.  First collecting the quads based on the Constraint, then moving the new quads into the new graph.
  """
  def process_quads(%GraphSpec{constraint: constraint} = graph_spec, info, quads, extra_quads) do
    ALog.di(graph_spec, "Process quads for GraphSpec graph_spec")
    ALog.di(quads, "Process quads for GraphSpec quads")

    Logging.EnvLog.inspect(graph_spec, :inspect_access_rights_processing,
      label: "processing for graph_spec"
    )

    Logging.EnvLog.inspect(quads, :inspect_access_rights_processing, label: "- quads to process")

    Logging.EnvLog.inspect(extra_quads, :inspect_access_rights_processing,
      label: "- background knowledge quads"
    )

    constraint
    |> Acl.GraphSpec.Constraint.Protocol.matching_quads(quads, extra_quads)
    |> Logging.EnvLog.inspect(:inspect_access_rights_processing,
      label: "matching quads for processing"
    )
    |> ALog.di("Matching quads")
    |> Enum.map(&alter_quad_graph(&1, graph_spec, info))
    |> ALog.di("Renamed quads")
    |> Logging.EnvLog.inspect(:inspect_access_rights_processing,
      label: "renamed quads in processing"
    )
    |> (fn new_quads -> quads ++ new_quads end).()
    |> Logging.EnvLog.inspect(:inspect_access_rights_processing,
      label: "resulting quads by processing"
    )
    |> ALog.di("All quads")
  end

  defp alter_quad_graph(quad, %GraphSpec{} = graph_spec, info) do
    new_graph =
      graph_spec
      |> matching_graph(info)
      |> wrap_graph

    %{quad | graph: Iri.from_iri_string(new_graph)}
  end

  defp wrap_graph(graph) do
    # TODO: escape graph content! << might lead to accidental injection!
    "<" <> graph <> ">"
  end

  defp matching_graph(%GraphSpec{graph: graph}, {_name, variables} = _auth_info) do
    graph <> Enum.join(variables, "/")
  end

  def process_query(%GraphSpec{} = graph_spec, info, query) do
    new_graph = matching_graph(graph_spec, info)

    new_query =
      query
      |> Manipulators.SparqlQuery.add_from_graph(new_graph)

    {new_query, [info]}
  end
end
