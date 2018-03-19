defmodule Sparql do
  @moduledoc """
  ## Overview
  This module offers some functionality to parse SPARQL queries. To do this I
  have build a parser with the :leex and :yecc erlang libraries.

  ## :leex and :yecc
  You can find the source files as well as the compiled erlang files
  for this under ../parser-generator/

  Since this uses raw erlang libraries under the hood all queries that get send
  are assumed to be single quoted strings

  ## TODOs
  TODO add a function to remove all graph statements
  TODO add a function to override all graph statements with a set of graph statements
  """

  @doc """
  Parses a SPARQL query that gets passed in a single quoted string
  (see erlang documentation on the issues with double quoted strings)

  ## Examples

       iex> Sparql.parse('SELECT ?s ?p ?o WHERE { ?s ?p ?o }')
       {:ok,
         {:sparql,
           {:select,
             {:"select-clause", {:"var-list", [variable: :s, variable: :p, variable: :o]}},
             {:where,
               [
                 {:"same-subject-path", {:subject, {:variable, :s}},
                   {:"predicate-list",
                   [
                     {{:predicate, {:variable, :p}},
                       {:"object-list", [object: {:variable, :o}]}}
             ]}}
           ]}}
         }
       }
  """
  def parse(raw_query) do
    raw_query |> tokenize |> do_parse
  end

  defp tokenize(raw_query) do
    :"sparql-tokenizer".string(raw_query)
  end

  defp do_parse({:ok, tokenized_query, _}) do
    :"sparql-parser".parse(tokenized_query)
  end

  defp do_parse({:error, _, _} = error_message) do
    error_message
  end

  @doc """
  Converts all same-subject-paths into simple subject paths
  in SPARQL itself this is the equivalent of converting.
  ```
    ?s ?p ?o ; ?p2 ?o2 , ?o3 .
  ```
  to
  ```
    ?s ?p ?o .
    ?s ?p2 ?o2 .
    ?s ?p2 ?o3 .
  ```

  ## Examples
       iex> Sparql.convert_to_simple_triples({:"same-subject-path", {:subject, {:variable, :s}},
       iex> {:"predicate-list",
       iex> [
       iex> {{:predicate, {:variable, :p}},
       iex> {:"object-list", [object: {:variable, :o}]}}
       iex> ]}})
       [
         {{:subject, {:variable, :s}}, {:predicate, {:variable, :p}}, {:object, {:object, {:variable, :o}}}}
       ]
  """
  def convert_to_simple_triples({:"same-subject-path", {:subject, subject}, {:"predicate-list", predicate_list}})do
    convert_to_simple_triples(subject, predicate_list)
  end

  defp convert_to_simple_triples(subject, predicate_list) do
    predicate_list
    |> Enum.map(fn({{:predicate, predicate}, {:"object-list", object_list}}) ->
        convert_to_simple_triples(subject, predicate, object_list) end)
    |> Enum.reduce(fn(x, acc) -> Enum.into(x, acc, fn(x) -> x end) end)
  end

  defp convert_to_simple_triples(subject, predicate, object_list) do
    Enum.map(object_list, fn(object) ->
      {{:subject, subject}, {:predicate, predicate}, {:object, object}} end)
  end
end
