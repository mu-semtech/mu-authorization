defprotocol Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol do
  alias Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol, as: Pr
  alias Updates.QueryAnalyzer.Iri, as: Iri

  @type t :: struct()

  @spec member?(Pr.t(), Iri.t()) :: true | false
  def member?(predicate_match, iri)
end
