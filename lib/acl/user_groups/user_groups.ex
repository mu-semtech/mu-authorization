alias Updates.QueryAnalyzer.Iri, as: Iri
alias Updates.QueryAnalyzer.Types.Quad, as: Quad

defmodule Acl.UserGroups do
  alias Acl.UserGroups.Config, as: Config
  alias Acl.GroupSpec, as: GroupSpec

  @doc """
  Filters the useage_groups for a particular useage.
  """
  @spec user_groups_for(Config.t(), GroupSpec.useage_method()) :: Config.t()
  def user_groups_for(user_groups, useage) do
    user_groups
    |> Enum.filter(fn user_group ->
      user_group
      |> Map.get(:useage)
      |> Enum.member?(useage)
    end)
  end

  @doc """
  Yields all the user groups for the supplied useage.
  """
  @spec for_use(GroupSpec.useage_method()) :: Config.t()
  def for_use(useage) do
    Config.user_groups()
    |> user_groups_for(useage)
  end

  @doc """
  Constructs acl right for a given graph and returns the access rights for the supplied quad.
  """
  @spec access_rights_for_quads([Quad.t()]) :: [Acl.allowed_groups()]
  def access_rights_for_quads(quads) do
    # hasConstraint( graph_spec, constraint )
    # && quad elementOf quads
    # && exists matching_quads( constraint, quad, [], true )
    # && has_graph( quad, graph )
    # && graph_access_rights_derivation( graph, graph_spec, access_right )
    # -> access_right elementOf solution

    # If a GraphSpec has a constraint
    # and a set of quads matches those constraints,
    # then we should check if the graph for any of those
    # constraints combined with the groupspec's access rights match the
    # graph of the quad.  For all those access rights where that holds,
    # they may have been impacted.

    Config.user_groups()
    # This first filter could be removed if the GraphCleanup is removed.
    |> Enum.filter(fn user_group ->
      case user_group do
        %Acl.GroupSpec.GraphCleanup{} -> nil
        %Acl.GroupSpec{} -> true
        _ -> raise "Don't understand user_group for discovering relevant access rights"
      end
    end)
    |> Enum.map(fn user_group ->
      user_group.graphs
      |> Enum.map(fn graph_spec ->

        matching_quads =
          Acl.GraphSpec.Constraint.Protocol.matching_quads(
            graph_spec.constraint,
            quads,
            [],
            true
          )

        relevant_graphs =
          matching_quads
          |> Enum.map(fn %Quad{graph: %Iri{ iri: graph }} -> Iri.unwrap_iri_string(graph) end)
          |> Enum.uniq()
          |> Enum.map(fn graph -> derive_access_rights(graph, graph_spec, user_group) end)
          |> Enum.filter(fn x -> not match?(nil, x) end)

        relevant_graphs
      end)
      |> Enum.flat_map(fn x -> x end)
      |> Enum.uniq()
    end)
    |> Enum.flat_map(fn x -> x end)
    |> Enum.uniq()
  end

  defp derive_access_rights(graph, graph_spec, group_spec) do
    # check if graph starts with graph_spec
    if String.starts_with?(graph, graph_spec.graph) do
      # see extract the variable attachments if they exist
      # use a real graph_spec thingy

      parameters =
        graph
        |> String.slice(String.length(graph_spec.graph)..String.length(graph))
        |> String.split("/")

      # TODO: if there are variable attachments, verify they match the
      # actual access rights

      # add the variable attachments to the graph based on the group_spec
      {group_spec.name, parameters}
    else
      nil
    end
  end
end
