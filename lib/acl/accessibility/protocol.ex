defprotocol Acl.Accessibility.Protocol do
  @type t :: Acl.Accessibility.Always.t() | Acl.Accessibility.ByQuery.t()

  # The result of this function should probably be something more
  # complex than [[String.t]].  The values of the arguments will need to
  # make sense.  A map or json-like representation are necessary.
  @spec accessible?(t(), Acl.GraphSpec.t(), Plug.Conn.t()) :: {:ok, [[String.t()]]} | {:fail}
  def accessible?(constraint, graph_spec, request)
end
