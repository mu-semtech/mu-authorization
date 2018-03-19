defmodule SparqlTest do
  use ExUnit.Case
  doctest Sparql

  test "parse the simplest SPARQL query" do
    simple_query = 'SELECT * WHERE { ?s ?p ?o }'
    standard_simple_query = {:ok,
                             {:sparql,
                              {:select, {:"select-clause", {:"var-list", :asterisk}},
                               {:where,
                                [
                                  {:"same-subject-path", {:subject, {:variable, :s}},
                                   {:"predicate-list",
                                    [
                                      {{:predicate, {:variable, :p}},
                                       {:"object-list", [object: {:variable, :o}]}}
                                    ]}}
                                ]}}}}
    parsed_simple_query = simple_query |> Sparql.parse

    assert parsed_simple_query == standard_simple_query
  end
end
