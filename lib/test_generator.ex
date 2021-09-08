defmodule Tester.Generator do
  @moduledoc """
  Tester.Generator module helps write regression tests.

  Run `iex -S mix run` next `Tester.Generator.generate_tests("test/generated_test.exs")` to create new regression tests.
  These tests test the sparql query parser.

  To add new tests add new `print_test` function invocations.
  This parses the query and creates a test that parsing the same query yields the same result (ignoring whitespace and string).

  Run all generated tests with `mix test --only generated`
  """

  @queries """
  ---SELECT 1---
  SELECT * WHERE { ?s ?p ?o}

  ---SELECT 2---
  SELECT * WHERE { GRAPH ?g { ?s ?p ?o} }

  ---SELECT 3---
  SELECT ?title WHERE { <http://example.org/book/book1> <http://purl.org/dc/elements/1.1/title> ?title . }

  ---SELECT 4---
  PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
    SELECT ?name ?mbox
    WHERE
      { ?x foaf:name ?name .
        ?x foaf:mbox ?mbox }

  ---SELECT 5---
  SELECT ?v WHERE { ?v ?p "abc"^^<http://example.org/datatype#specialDatatype> }

  ---SELECT 6---
  PREFIX foaf:    <http://xmlns.com/foaf/0.1/>
      SELECT ?nameX ?nameY ?nickY
      WHERE
        { ?x foaf:knows ?y ;
             foaf:name ?nameX .
          ?y foaf:name ?nameY .
          OPTIONAL { ?y foaf:nick ?nickY }
        }

  ---SELECT 7---
  PREFIX foaf:    <http://xmlns.com/foaf/0.1/>
  PREFIX vcard:   <http://www.w3.org/2001/vcard-rdf/3.0#>

  CONSTRUCT { ?x  vcard:N _:v .
              _:v vcard:givenName ?gname .
              _:v vcard:familyName ?fname }
  WHERE
    {
      { ?x foaf:firstname ?gname } UNION  { ?x foaf:givenname   ?gname } .
      { ?x foaf:surname   ?fname } UNION  { ?x foaf:family_name ?fname } .
    }

  ---SELECT 8---
  PREFIX foaf:    <http://xmlns.com/foaf/0.1/>
  ASK  { ?x foaf:name  "Alice" ;
            foaf:mbox  <mailto:alice@work.example> }

  ---SELECT 9---
  PREFIX a:      <http://www.w3.org/2000/10/annotation-ns#>
  PREFIX dc:     <http://purl.org/dc/elements/1.1/>
  PREFIX xsd:    <http://www.w3.org/2001/XMLSchema#>

  SELECT ?annot
  WHERE { ?annot  a:annotates  <http://www.w3.org/TR/rdf-sparql-query/> .
          ?annot  dc:date      ?date .
          FILTER ( ?date > "2005-01-01T00:00:00Z"^^xsd:dateTime ) }

  ---SELECT 10---
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX dc:   <http://purl.org/dc/elements/1.1/>
  PREFIX xsd:   <http://www.w3.org/2001/XMLSchema#>
  SELECT ?name
    WHERE { ?x foaf:givenName  ?givenName .
            OPTIONAL { ?x dc:date ?date } .
            FILTER ( bound(?date) ) }
  """

  defp print_test(file, test_name, query, indent) do
    expected = query |> Parser.parse_query_full()

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

  defp print_bench(file, test_name, query, indent) do
    query = query |> String.trim()
    bench = fn -> query |> Parser.parse_query_full() end
    bench_times = benchmark(bench, 100, false)
    bench_times_warmed_up = benchmark(bench, 100, true)

    IO.write(file, ~s(#{indent}@tag :generated_bench\n))
    IO.write(file, ~s(#{indent}test "#{test_name}" do\n))
    IO.write(file, ~s(\n))
    IO.write(file, ~s(#{indent}#{indent}query = #{inspect(query)}\n))
    IO.write(file, ~s(#{indent}#{indent}bench = fn -> query |> TestHelper.parse end\n))
    IO.write(file, ~s[#{indent}#{indent}bench_times = Tester.Generator.benchmark(bench, 100, false)\n])
    IO.write(file, ~s(\n))
    IO.write(file, ~s[#{indent}#{indent}IO.puts("\n------------------")\n])
    IO.write(file, ~s[#{indent}#{indent}IO.puts(#{inspect(test_name)})\n])
    IO.write(file, ~s[#{indent}#{indent}IO.inspect(#{inspect(bench_times)}, label: "was")\n])
    IO.write(file, ~s[#{indent}#{indent}IO.inspect(#{inspect(bench_times_warmed_up)}, label: "was with warmup")\n])
    IO.write(file, ~s[#{indent}#{indent}IO.inspect(bench_times, label: "now")\n])
    IO.write(file, ~s(\n))
    IO.write(file, ~s[#{indent}#{indent}assert true\n])
    IO.write(file, ~s(#{indent}end\n))
    IO.write(file, ~s(\n))
  end

  defp generate_with(f) do
    is_blank = fn x -> x |> String.trim() |> String.length() |> Kernel.>(0) end

    queries =
      Regex.split(~r/---[^-]+---/, @queries |> String.trim(), include_captures: true)
      |> Enum.filter(is_blank)
      |> Enum.chunk_every(2)

    queries
    |> Enum.each(fn [name, query] ->
      [_, name] = Regex.run(~r/---(.*)---/, name)
      f.(name, query)
    end)
  end

  def generate_tests(file \\ "test/generated/test_test.exs") do
    {:ok, file} = File.open(file, [:write])
    indent = "  "

    IO.write(file, ~s(defmodule Test.Sparql.Generated do\n))
    IO.write(file, ~s(#{indent}use ExUnit.Case\n\n))

    generate_with(&print_test(file, "test: " <> &1, &2, indent))

    IO.write(file, ~s(end\n))
    File.close(file)
  end

  def generate_benches(file \\ "test/generated/bench_test.exs") do
    {:ok, file} = File.open(file, [:write])
    indent = "  "

    IO.write(file, ~s(defmodule Test.Sparql.Bench.Generated do\n))
    IO.write(file, ~s(#{indent}use ExUnit.Case\n\n))

    generate_with(&print_bench(file, "bench: " <> &1, &2, indent))

    IO.write(file, ~s(end\n))
    File.close(file)
  end

  def get_queries() do
    @queries
  end

  import Enum, only: [sum: 1]
  import :math, only: [sqrt: 1, pow: 2]

  def standard_deviation(data) do
    m = mean(data)
    data |> variance(m) |> mean |> sqrt
  end

  def mean(data) do
    sum(data) / length(data)
  end

  def variance(data, mean) do
    for n <- data, do: pow(n - mean, 2)
  end

  def median(data) do
    data = data |> Enum.sort()
    mid = div(length(data), 2)

    if rem(length(data), 2) == 0 do
      (Enum.at(data, mid) + Enum.at(data, mid + 1)) / 2
    else
      Enum.at(data, mid)
    end
  end

  def benchmark(f, times \\ 100, warmup \\ true) do
    if warmup do
      Stream.repeatedly(fn -> {} end)
      |> Enum.take(10)
      |> Enum.each(fn _x -> f.() end)
    end

    times =
      Stream.repeatedly(fn -> {} end)
      |> Enum.take(times)
      |> Enum.map(fn _ ->
        f
        |> :timer.tc()
        |> elem(0)
      end)

    [median(times), mean(times), standard_deviation(times)]
  end
end
