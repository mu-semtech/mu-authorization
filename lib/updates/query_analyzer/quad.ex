alias Updates.QueryAnalyzer.Types.Quad, as: Quad
alias Updates.QueryAnalyzer.Variable, as: Var

defmodule Quad do
  defstruct [:graph, :subject, :predicate, :object]

  # TODO: further specify the definition of subject, predicate, object
  @type t :: %Quad{graph: String.t(), subject: any, predicate: any, object: any}

  def make(graph, subject, predicate, object) do
    %Quad{graph: graph, subject: subject, predicate: predicate, object: object}
  end

  @doc """
  Appends to lists of quads.  Simple as can be.
  """
  def append(quad_list_1, quad_list_2) do
    quad_list_1 ++ quad_list_2
  end

  @doc """
  Creates a quad from options, as discovered by the query analyzer
  """
  def from_options(%{default_graph: graph, subject: subject, predicate: predicate, object: object}) do
    %Quad{graph: graph, subject: subject, predicate: predicate, object: object}
  end

  @doc """
  Yields the quad as an array, which helps processing its sub-elements.
  """
  def as_list(%Quad{graph: graph, subject: subject, predicate: predicate, object: object}) do
    [graph, subject, predicate, object]
  end

  @doc """
  Inverse operation of as_list
  """
  def from_list([graph, subject, predicate, object]) do
    %Quad{graph: graph, subject: subject, predicate: predicate, object: object}
  end

  def has_var?(%Quad{graph: graph, subject: subject, predicate: predicate, object: object}) do
    Var.is_var(object) ||
      Var.is_var(subject) ||
      Var.is_var(graph) ||
      Var.is_var(predicate)
  end
end
