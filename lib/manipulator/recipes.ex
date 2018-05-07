defmodule Manipulators.Recipes do
  @moduledoc """
  Contains standard recipes for manipulating queries.  Often as example.
  """

  @doc """
    Fully append a query graph
  """
  def query_string_fully_append_query_graph(query_string) do
    Parser.parse_query( query_string )
    |> Generator.Result.extract_element
    |> Manipulators.SparqlQuery.add_graph( "http://lblod.info" )
    |> Manipulators.SparqlQuery.add_from_graph( "http://mu.semte.ch/hello-world" )
    |> Manipulators.SparqlQuery.add_from_graph( "http://mu.semte.ch/ext/my-stuff" )
    |> Regen.make_generator
    |> Regen.Result.all
  end

  def set_multiple_graphs( element ) do
    element
    |> Manipulators.SparqlQuery.add_graph( "http://mu.semte.ch/application" )
    |> Manipulators.SparqlQuery.add_from_graph( "http://mu.semte.ch/application-extensions" )
    |> Manipulators.SparqlQuery.add_from_graph( "http://mu.semte.ch/application-basics" )
  end

  def set_application_graph( element ) do
    element
    |> Manipulators.SparqlQuery.add_graph( "http://mu.semte.ch/application" )
  end

end
