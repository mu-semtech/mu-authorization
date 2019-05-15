defmodule Manipulators.Recipes do
  @moduledoc """
  Contains standard recipes for manipulating queries.  Often as example.
  """

  @doc """
    Fully append a query graph
  """
  @spec query_string_fully_append_query_graph(String.t()) :: String.t() | {:fail}
  def query_string_fully_append_query_graph(query_string) do
    case Parser.parse_query_first(query_string) do
      {:fail} ->
        {:fail}

      {_, element} ->
        element
        |> Manipulators.SparqlQuery.add_graph("http://lblod.info")
        |> Manipulators.SparqlQuery.add_from_graph("http://mu.semte.ch/hello-world")
        |> Manipulators.SparqlQuery.add_from_graph("http://mu.semte.ch/ext/my-stuff")
        |> Regen.make_generator()
        |> Regen.Result.all()
    end
  end

  @spec set_multiple_graphs(InterpreterTerms.query()) :: InterpreterTerms.query()
  def set_multiple_graphs(element) do
    element
    |> Manipulators.SparqlQuery.add_graph("http://mu.semte.ch/application")
    |> Manipulators.SparqlQuery.add_from_graph("http://mu.semte.ch/application-extensions")
    |> Manipulators.SparqlQuery.add_from_graph("http://mu.semte.ch/application-basics")
  end

  @spec set_application_graph(InterpreterTerms.query()) :: InterpreterTerms.query()
  def set_application_graph(element) do
    element
    |> Manipulators.SparqlQuery.add_graph("http://mu.semte.ch/application")
  end

  @spec set_from_graph(InterpreterTerms.query()) :: InterpreterTerms.query()
  def set_from_graph(element) do
    element
    |> Manipulators.SparqlQuery.add_from_graph("http://mu.semte.ch/application")
  end

  @spec add_prefixes(InterpreterTerms.query(), [Manipulators.SparqlQuery.prefix()]) ::
          InterpreterTerms.query()
  def add_prefixes(element, prefixes) do
    Enum.reduce(prefixes, element, fn elt, acc ->
      add_prefix(acc, elt)
    end)
  end

  @spec add_prefix(InterpreterTerms.query(), Manipulators.SparqlQuery.prefix()) ::
          InterpreterTerms.query()
  def add_prefix(element, {_prefix, _printable_iri} = prefix) do
    element
    |> Manipulators.SparqlQuery.add_prefix(prefix)
  end
end
