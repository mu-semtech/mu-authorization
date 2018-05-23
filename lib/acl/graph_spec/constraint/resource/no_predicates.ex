defmodule Acl.GraphSpec.Constraint.Resource.NoPredicates do
  defstruct []

  @moduledoc """
  This predicate matcher does not allow any predicates.
  """

  defimpl Acl.GraphSpec.Constraint.Resource.PredicateMatchProtocol do
    def member?( %Acl.GraphSpec.Constraint.Resource.NoPredicates{}, _ ) do
      false
    end
  end
end
