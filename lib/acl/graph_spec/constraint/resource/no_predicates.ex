alias Updates.QueryAnalyzer.Iri, as: Iri

defmodule Acl.GraphSpec.Constraint.Resource.NoPredicates do
  defstruct [except: []]

  @moduledoc """
  This predicate matcher does not allow any predicates.
  """

  defimpl Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol do
    def member?( %Acl.GraphSpec.Constraint.Resource.NoPredicates{except: except}, %Iri{ iri: iri_value } ) do
      Enum.find( except, fn (elt) -> elt == iri_value end )
    end
  end
end
