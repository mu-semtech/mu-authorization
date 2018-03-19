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

  test "parse a wrong SPARQL query" do
    simple_query = 'SELECT * WHERE '
    {response_code, _} = simple_query |> Sparql.parse
    assert :error == response_code
  end

  test "reduce a same-subject-path to an array of simple-subject-path object" do
    same_subject_path = {:"same-subject-path", {:subject, {:variable, :s}},
                         {:"predicate-list",
                          [
                            {{:predicate, {:variable, :p}},
                             {:"object-list", [object: {:variable, :o}]}}
                          ]}}
    simple_subject_path = [{{:subject, {:variable, :s}},
                            {:predicate, {:variable, :p}},
                            {:object, {:object, {:variable, :o}}}}]

    assert simple_subject_path == Sparql.convert_to_simple_triples(same_subject_path)
  end

  test "a more complex same-subject-path test where we test this 3 levels deep" do
    same_subject_path = {:"same-subject-path", {:subject, {:variable, :s}},
                         {:"predicate-list",
                          [
                            {{:predicate, {:variable, :p}},
                             {:"object-list", [object: {:variable, :o}]}},
                            {{:predicate, {:variable, :p2}},
                             {:"object-list",
                              [object: {:variable, :o2}, object: {:variable, :o3}]}}
                          ]}}
    simple_subject_path = [
      {{:subject, {:variable, :s}}, {:predicate, {:variable, :p}},
       {:object, {:object, {:variable, :o}}}},
      {{:subject, {:variable, :s}}, {:predicate, {:variable, :p2}},
       {:object, {:object, {:variable, :o2}}}},
      {{:subject, {:variable, :s}}, {:predicate, {:variable, :p2}},
       {:object, {:object, {:variable, :o3}}}}
    ]

    assert simple_subject_path == Sparql.convert_to_simple_triples(same_subject_path)
  end
end
