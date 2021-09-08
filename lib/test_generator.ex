defmodule Tester.Generator do
  @moduledoc """
  Tester.Generator module helps write regression tests.

  Run `iex -S mix run` next `Tester.Generator.generate_tests("test/generated_test.exs")` to create new regression tests.
  These tests test the sparql query parser.

  To add new tests add new `print_test` function invocations.
  This parses the query and creates a test that parsing the same query yields the same result (ignoring whitespace and string).

  Run all generated tests with `mix test --only generated`
  """

  defp print_test(file, test_name, query) do
    expected = query |> Parser.parse_query_full()
    indent = "  "
    IO.write(file, ~s(#{indent}@tag :generated\n))
    IO.write(file, ~s(#{indent}test "#{test_name}" do\n))
    IO.write(file, ~s(\n))
    IO.write(file, ~s(#{indent}#{indent}query = #{inspect(query)}\n))
    IO.write(file, ~s(#{indent}#{indent}expected = #{inspect(expected)}\n))
    IO.write(file, ~s(#{indent}#{indent}actual = query |> TestHelper.parse\n))
    IO.write(file, ~s(\n))

    IO.write(
      file,
      ~s[#{indent}#{indent}assert TestHelper.match_ignore_whitespace_and_string(expected, actual)\n]
    )

    IO.write(file, ~s(#{indent}end\n))
    IO.write(file, ~s(\n))
  end

  def generate_tests(file \\ "test.txt") do
    {:ok, file} = File.open(file, [:write])
    indent = "  "
    IO.write(file, ~s(defmodule GeneratedSparqlTest do\n))
    IO.write(file, ~s(#{indent}use ExUnit.Case\n\n))
    print_test(file, "basic query 1", "SELECT * WHERE { ?s ?p ?o}")
    print_test(file, "basic query 2", "SELECT * WHERE { GRAPH ?g { ?s ?p ?o} }")

    print_test(
      file,
      "basic query 3",
      "SELECT ?title WHERE { <http://example.org/book/book1> <http://purl.org/dc/elements/1.1/title> ?title . }"
    )

    # 'foaf:name ?name' gets matched as 'foaf:name ?' crash the '?' is matched as optional PathMod
    print_test(file, "basic query 4", "PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
    SELECT ?name ?mbox
    WHERE
      { ?x foaf:name ?name .
        ?x foaf:mbox ?mbox }")
    print_test(file, "basic select query 5", ~s(SELECT ?v WHERE { ?v ?p "cat" }))

    print_test(
      file,
      "basic select query 6",
      ~s(SELECT ?v WHERE { ?v ?p "abc"^^<http://example.org/datatype#specialDatatype> })
    )

    print_test(
      file,
      "select query 7",
      ~s[PREFIX foaf:    <http://xmlns.com/foaf/0.1/>
      SELECT ?nameX ?nameY ?nickY
      WHERE
        { ?x foaf:knows ?y ;
             foaf:name ?nameX .
          ?y foaf:name ?nameY .
          OPTIONAL { ?y foaf:nick ?nickY }
        }]
    )

    print_test(
      file,
      "select query 8",
      ~s[PREFIX foaf:    <http://xmlns.com/foaf/0.1/>
      PREFIX vcard:   <http://www.w3.org/2001/vcard-rdf/3.0#>

      CONSTRUCT { ?x  vcard:N _:v .
                  _:v vcard:givenName ?gname .
                  _:v vcard:familyName ?fname }
      WHERE
       {
          { ?x foaf:firstname ?gname } UNION  { ?x foaf:givenname   ?gname } .
          { ?x foaf:surname   ?fname } UNION  { ?x foaf:family_name ?fname } .
       }]
    )

    print_test(
      file,
      "select query 9",
      ~s[PREFIX foaf:    <http://xmlns.com/foaf/0.1/>
      ASK  { ?x foaf:name  "Alice" ;
                foaf:mbox  <mailto:alice@work.example> }]
    )

    print_test(
      file,
      "select query 10",
      ~s[PREFIX a:      <http://www.w3.org/2000/10/annotation-ns#>
      PREFIX dc:     <http://purl.org/dc/elements/1.1/>
      PREFIX xsd:    <http://www.w3.org/2001/XMLSchema#>

      SELECT ?annot
      WHERE { ?annot  a:annotates  <http://www.w3.org/TR/rdf-sparql-query/> .
              ?annot  dc:date      ?date .
              FILTER ( ?date > "2005-01-01T00:00:00Z"^^xsd:dateTime ) }]
    )

    print_test(
      file,
      "select query 11",
      ~s[
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX dc:   <http://purl.org/dc/elements/1.1/>
PREFIX xsd:   <http://www.w3.org/2001/XMLSchema#>
SELECT ?name
 WHERE { ?x foaf:givenName  ?givenName .
         OPTIONAL { ?x dc:date ?date } .
         FILTER ( bound(?date) ) }
      ]
    )

    IO.write(file, ~s(end\n))

    File.close(file)
  end
end
