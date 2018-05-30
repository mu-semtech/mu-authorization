alias Acl.Accessibility.Always, as: AlwaysAccessible
alias Acl.Accessibility.ByQuery, as: AccessByQuery
alias Acl.GraphSpec.Constraint.Resource.AllPredicates, as: AllPredicates
alias Acl.GraphSpec.Constraint.Resource.NoPredicates, as: NoPredicates
alias Acl.GraphSpec.Constraint.Resource, as: ResourceConstraint
alias Acl.GraphSpec, as: GraphSpec
alias Acl.GroupSpec, as: GroupSpec
alias Acl.GroupSpec.GraphCleanup, as: GraphCleanup

defmodule Acl.Config.UserGroups do
  def user_groups do
    "These elements are walked from top to bottom.  Each of them may
    alter the quads to which the current query applies.  Quads are
    represented in three sections: current_source_quads,
    removed_source_quads, new_quads.  The quads may be calculated in
    many ways.  The useage of a GroupSpec and GraphCleanup are common."
    [ %GroupSpec{
        name: "shared",
        access: %AlwaysAccessible{},
        graphs: [ %GraphSpec{
                    graph: "http://mu.semte.ch/graphs/shared",
                    constraint: %ResourceConstraint{
                      source_graph: "http://mu.semte.ch/application",
                      resource_type: "http://mu.semte.ch/ext/Product",
                      predicates: %AllPredicates{},
                      inverse_predicates: %NoPredicates{} } },
                  %GraphSpec{
                    graph: "http://mu.semte.ch/graphs/contacts",
                    constraint: %ResourceConstraint{
                      source_graph: "http://mu.semte.ch/application",
                      resource_type: "http://mu.semte.ch/ext/Contact",
                      predicates: %AllPredicates{},
                      inverse_predicates: %NoPredicates{} } } ] },
      %GroupSpec{
        name: "users",
        access: %AccessByQuery{
          vars: ["user_uuid"],
          query: "PREFIX foaf: <http://xmlns.com/foaf/0.1/> PREFIX musession: <https://mu.semte.ch/vocabularies/session/> PREFIX mu: <http://mu.semte.ch/vocabularies/core/> SELECT ?user_uuid WHERE { <SESSION_ID> mu:uuid ?user_uuid. }"
                # "PREFIX foaf: <http://xmlns.com/foaf/0.1/> PREFIX musession: <https://mu.semte.ch/vocabularies/session/> PREFIX mu: <http://mu.semte.ch/vocabularies/core/> SELECT ?user_uuid WHERE { <SESSION_ID> musession:account/^foaf:account/mu:uuid ?user_uuid }"
        },
        graphs: [ %GraphSpec{
                    graph: "http://mu.semte.ch/graphs/users/",
                    constraint: %ResourceConstraint{
                      resource_type: "http://mu.semte.ch/ext/Basket",
                      predicates: %AllPredicates{},
                      inverse_predicates: %NoPredicates{} } } ] },
      %GraphCleanup{
        originating_graph: "http://mu.semte.ch/application"
      }
    ]
  end
end
