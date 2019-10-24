defprotocol Acl.GraphSpec.Constraint.Protocol do
  alias Acl.GraphSpec.Constraint.Protocol, as: Pr
  alias Updates.QueryAnalyzer.Types.Quad, as: Quad

  @type t :: struct()

  @doc """
  Filters out the quads which match with the supplied model.  Only
  returns the matching quads.  The optional second argument provides
  extra quads which can be used to determine whether some quads are to
  be included or not.  For instance, we may want to know whether an
  object is of a certain type.
  """
  @spec matching_quads(Pr.t(), [Quad], [Quad]) :: [Quad]
  def matching_quads(constraint, quads, extra_quads \\ [])
end
