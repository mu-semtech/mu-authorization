defmodule Acl.GraphSpec.Constraint.Resource.AllPredicates do
  defstruct []

  @moduledoc """
  This predicate matcher allows all predicates.
  """

  defimpl Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol do
    def member?( %Acl.GraphSpec.Constraint.Resource.AllPredicates{}, _ ) do
      true
    end
  end
end
