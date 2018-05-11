alias Updates.QueryAnalyzer.Types.Quad, as: Quad

defmodule Quad do
  defstruct [:graph, :subject, :predicate, :object]

  def make( graph, subject, predicate, object ) do
    %Quad{ graph: graph, subject: subject, predicate: predicate, object: object }
  end

  @doc """
  Appends to lists of quads.  Simple as can be.
  """
  def append( quad_list_1, quad_list_2 ) do
    quad_list_1 ++ quad_list_2
  end

  @doc """
  Creates a quad from options, as discovered by the query analyzer
  """
  def from_options( %{ default_graph: graph, subject: subject, predicate: predicate, object: object } ) do
    %Quad{ graph: graph, subject: subject, predicate: predicate, object: object }
  end

end
