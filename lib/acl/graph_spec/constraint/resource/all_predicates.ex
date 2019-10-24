defmodule Acl.GraphSpec.Constraint.Resource.AllPredicates do
  alias Updates.QueryAnalyzer.Iri, as: Iri

  defstruct except: []

  @moduledoc """
  This predicate matcher allows all predicates.
  """

  defimpl Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol do
    def member?(%Acl.GraphSpec.Constraint.Resource.AllPredicates{except: except}, %Iri{
          iri: iri_value
        }) do
      # TODO: wrapping of Iri should be abstracted
      wrapped_except = Enum.map(except, fn x -> "<" <> x <> ">" end)

      !Enum.find(wrapped_except, fn elt -> elt == iri_value end)
    end
  end
end
