alias Updates.QueryAnalyzer.Types.Quad, as: Quad

defmodule Quad do
  alias Updates.QueryAnalyzer.Variable, as: Var

  defstruct [:graph, :subject, :predicate, :object]

  # TODO: further specify the definition of subject, predicate, object
  @opaque value :: Updates.QueryAnalyzer.value()
  @type t :: %Quad{graph: value, subject: value, predicate: value, object: value}

  @doc """
  Constructs a new quad.
  """
  @spec make(value, value, value, value) :: t
  def make(graph, subject, predicate, object) do
    %Quad{graph: graph, subject: subject, predicate: predicate, object: object}
  end

  @doc """
  Appends to lists of quads.  Simple as can be.
  """
  @spec append([t], [t]) :: [t]
  def append(quad_list_1, quad_list_2) do
    quad_list_1 ++ quad_list_2
  end

  @doc """
  Creates a quad from options, as discovered by the query analyzer
  """
  # TODO: specify each of these "any" statements
  @spec from_options(%{default_graph: value, subject: value, predicate: value, object: value}) ::
          t
  def from_options(%{default_graph: graph, subject: subject, predicate: predicate, object: object}) do
    %Quad{graph: graph, subject: subject, predicate: predicate, object: object}
  end

  @doc """
  Yields the quad as an array, which helps processing its sub-elements.
  """
  # TODO: specify each of these "any" statements
  @spec as_list(t) :: [value]
  def as_list(%Quad{graph: graph, subject: subject, predicate: predicate, object: object}) do
    [graph, subject, predicate, object]
  end

  @doc """
  Inverse operation of as_list
  """
  @spec from_list([value]) :: t
  def from_list([graph, subject, predicate, object]) do
    %Quad{graph: graph, subject: subject, predicate: predicate, object: object}
  end

  @doc """
  Yields a truethy response iff there is a variable in the quad.
  """
  @spec has_var?(t) :: boolean
  def has_var?(%Quad{graph: graph, subject: subject, predicate: predicate, object: object}) do
    Var.is_var(object) ||
      Var.is_var(subject) ||
      Var.is_var(graph) ||
      Var.is_var(predicate)
  end
end
