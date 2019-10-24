defprotocol Acl.GroupSpec.Protocol do
  # alias Acl.Accessibility.Protocol, as: APr
  alias Acl.GroupSpec.Protocol, as: GPr

  # struct()
  @type t :: Acl.GroupSpec.t() | Acl.GroupSpec.GraphCleanup.t(),
  @type query :: struct()
  @type matched_user_group :: {String.t(), [String.t()]}

  @doc """
  Indicates whether or not the given group_spec is accessible for the
  current user.  This item could be cached in the future based on the
  accessibility response.
  """
  @spec accessible?(t(), Plug.Conn.t()) :: {:ok, [GPr.matched_user_group()]} | {:fail}
  def accessible?(group_spec, request)

  @doc """
  Processing of a set of quads is hanlded by this method.  It
  transforms the supplied set of quads to a new set of quads.
  """
  @spec process(t(), GPr.matched_user_group(), [Quad]) :: [Quad]
  def process(group_spec, matched_user_group, quads)

  @doc """
  Rewrites a SPARQL GET query so it matches the required access
  rights.  In practice, this boils down to rewriting the query so only
  allowed graphs will be queried.

  The returned array of APr.matched_user_group contains all of the user groups
  which could have added content to the response.  An empty array
  means no response could be supplied by this processing.
  """
  @spec process_query(t(), GPr.matched_user_group(), GPr.query()) ::
          {GPr.query(), [GPr.matched_user_group()]}
  def process_query(group_spec, matched_user_group, query)
end
