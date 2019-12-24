defmodule Acl.GroupSpec do
  alias Acl.GroupSpec, as: GroupSpec
  alias Acl.GraphSpec, as: GraphSpec

  require Logger
  require ALog

  @type t :: %GroupSpec{
          name: String.t(),
          access: Acl.Accessibility.Protocol.t(),
          graphs: GraphSpec.t(),
          useage: [useage_method]
        }
  @type useage_method :: SparqlClient.query_types

  defstruct [:name, :access, :graphs, :useage]

  @moduledoc """
  The GroupSpec indicates groups to which a user has access.  Where
  the triples should go is defined in the graphs section.  Whether or
  not access is given, depends on the access key, and the name of the
  group is mentioned in the name property.

  These Groupspecs may be shared between reading and updating.  The
  access definition works in the same way, though the specific
  authorization may differ in practical instantiations.  Selection of
  what the selection is allowed to be used for is configured using the
  :useage keyword.
  """

  defimpl Acl.GroupSpec.Protocol do
    @spec accessible?(Acl.GroupSpec.Protocol.t(), Plug.Conn.t()) ::
            {:fail} | {:ok, [Acl.GroupSpec.Protocol.matched_user_group()]}
    def accessible?(%GroupSpec{access: access, name: name} = group_spec, request) do
      case Acl.Accessibility.Protocol.accessible?(access, group_spec, request) do
        {:fail} ->
          {:fail}

        {:ok, args} ->
          # Emit an array of solutions when they are available
          solutions =
            args
            |> Enum.map(fn vars -> {name, vars} end)

          {:ok, solutions}
      end
    end

    def process(%GroupSpec{} = group_spec, info, quads) do
      GroupSpec.process(group_spec, info, quads)
    end

    def process_query(%GroupSpec{} = group_spec, info, query) do
      Acl.GroupSpec.process_query(group_spec, info, query)
    end
  end

  def process(%GroupSpec{graphs: graph_specs}, info, quads) do
    # TODO: we should accept extra quads in order to limit the amount
    # of queries to be executed on the server in the long run.
    ALog.di(graph_specs, "Processing graph specs")
    ALog.di(quads, "Processing quads in graph_specs")

    Logging.EnvLog.inspect(graph_specs, :inspect_access_rights_processing,
      label: "processing specification"
    )

    graph_specs
    # We should cache and supply extra quads
    |> Enum.flat_map(&Acl.GraphSpec.process_quads(&1, info, quads, []))
    |> Logging.EnvLog.inspect(:inspect_access_rights_processing, label: "processing specification")
    |> ALog.di("Flat mapped processed quads")
    # TODO We should do a uniq_by and supply the IRI instead
    |> Enum.uniq()
  end

  def process_query(%GroupSpec{graphs: graph_specs}, info, query) do
    Logging.EnvLog.inspect(graph_specs, :inspect_access_rights_processing,
      label: "processing specification"
    )

    graph_specs
    |> Enum.reduce({query, []}, fn graph_spec, {query, auths} ->
      Logging.EnvLog.inspect(
        Regen.result(query),
        :inspect_access_rights_processing,
        label: "ACL graph_spec initial query"
      )

      {new_query, new_auths} = Acl.GraphSpec.process_query(graph_spec, info, query)

      Logging.EnvLog.inspect(
        Regen.result(new_query),
        :inspect_access_rights_processing,
        label: "ACL graph_spec transformed query"
      )

      {new_query, auths ++ new_auths}
    end)
  end
end
