alias Acl.Accessibility.Protocol, as: APr
alias Acl.GroupSpec.Protocol, as: GPr

defprotocol Acl.GroupSpec.Protocol do
  @type t :: struct()
  @type request :: struct()
  @type user_group :: {String.t, [String.t]}

  @doc """
  Indicates whether or not the given group_spec is accessible for the
  current user.  This item could be cached in the future based on the
  accessibility response.
  """
  @spec accessible?( GPr.t, GPr.request ) :: { :ok, [GPr.user_group] } | false
  def accessible?( group_spec, request )

  @doc """
  Processing of a set of quads is hanlded by this method.  It
  transforms the supplied set of quads to a new set of quads.
  """
  @spec process( GPr.t, [Quad] ) :: [Quad]
  def process( group_spec, quads )
end
