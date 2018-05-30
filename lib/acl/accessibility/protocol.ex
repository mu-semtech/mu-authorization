alias Acl.Accessibility.Protocol, as: Pr
alias Acl.GroupSpec.Protocol, as: GPr

defprotocol Acl.Accessibility.Protocol do
  @type t :: struct()
  @type graph_spec :: Acl.GraphSpec

  # The result of this function should probably be something more
  # complex than [[String.t]].  The values of the arguments will need to
  # make sense.  A map or json-like representation are necessary.
  @spec accessible?( Pr.t, Acl.GraphSpec, GPr.request ) :: { :ok, [[String.t]] } | { :fail }
  def accessible?( constraint, graph_spec, request )
end
