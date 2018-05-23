alias Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol, as: Pr
alias Updates.QueryAnalyzer.Iri, as: Iri


defprotocol Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol do
  @type t :: struct()

  @spec member?( Pr.t, Iri ) :: [true | false]
  def member?( predicate_match, iri )
end
