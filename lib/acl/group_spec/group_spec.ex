alias Acl.GroupSpec, as: GroupSpec

defmodule Acl.GroupSpec do
  defstruct [ :name, :access, :graphs ]

  @moduledoc """
  The GroupSpec indicates groups to which a user has access.  Where
  the triples should go is defined in the graphs section.  Whether or
  not access is given, depends on the access key, and the name of the
  group is mentioned in the name property.

  These Groupspecs may be shared between reading and updating.  The
  access definition works in the same way, though the specific
  authorization may differ in practical instantiations.
  """

  defimpl Acl.GroupSpec.Protocol do
    def accessible?( %GroupSpec{ access: access, name: name } = group_spec, request ) do
      case Acl.Accessibility.Protocol.accessible?( access, group_spec, request ) do
        { :fail } -> { :fail }
        { :ok, args } ->
          # Emit an array of solutions when they are available
          solutions =
            args
            |> Enum.map( fn (vars) -> { name, vars } end )
          { :ok, solutions }
      end
    end

    def process( %GroupSpec{} = group_spec, info, quads ) do
      GroupSpec.process( group_spec, info, quads )
    end
  end

  def process( %GroupSpec{ graphs: graph_specs }, info, quads ) do
    # TODO: we should accept extra quads in order to limit the amount
    # of queries to be executed on the server in the long run.
    graph_specs
    |> Enum.flat_map( &Acl.GraphSpec.process_quads( &1, info, quads, [] ) ) # We should cache and supply extra quads
    |> IO.inspect( label: "Flat mapped processed quads" )
    |> Enum.uniq # TODO We should do a uniq_by and supply the IRI instead
  end

end
