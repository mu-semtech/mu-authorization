defmodule Test.Sparql.Bench.Generated do
  use ExUnit.Case

  @tag :generated_bench
  test "bench: SELECT 1" do

    query = "SELECT * WHERE { ?s ?p ?o}"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 1")
    IO.inspect([698.5, 749.34, 364.11416396509486], label: "was")
    IO.inspect([705.5, 744.47, 236.01145967939775], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 2" do

    query = "SELECT * WHERE { GRAPH ?g { ?s ?p ?o} }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 2")
    IO.inspect([1202.5, 1461.61, 700.9569729305789], label: "was")
    IO.inspect([1150.0, 1256.66, 326.91085084469125], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 3" do

    query = "SELECT ?title WHERE { <http://example.org/book/book1> <http://purl.org/dc/elements/1.1/title> ?title . }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 3")
    IO.inspect([1298.5, 1460.62, 854.3563984661203], label: "was")
    IO.inspect([1484.5, 1701.46, 707.8477579253889], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 4" do

    query = "PREFIX foaf:   <http://xmlns.com/foaf/0.1/>\n  SELECT ?name ?mbox\n  WHERE\n    { ?x foaf:name ?name .\n      ?x foaf:mbox ?mbox }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 4")
    IO.inspect([2071.0, 2224.42, 556.5947750383576], label: "was")
    IO.inspect([1929.5, 2084.17, 355.3209831968836], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 5" do

    query = "SELECT ?v WHERE { ?v ?p \"abc\"^^<http://example.org/datatype#specialDatatype> }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 5")
    IO.inspect([1287.0, 1434.92, 609.9933881608882], label: "was")
    IO.inspect([1239.0, 1310.64, 212.752791756066], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 6" do

    query = "PREFIX foaf:    <http://xmlns.com/foaf/0.1/>\n    SELECT ?nameX ?nameY ?nickY\n    WHERE\n      { ?x foaf:knows ?y ;\n           foaf:name ?nameX .\n        ?y foaf:name ?nameY .\n        OPTIONAL { ?y foaf:nick ?nickY }\n      }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 6")
    IO.inspect([4047.5, 4193.17, 694.1503591441842], label: "was")
    IO.inspect([3969.0, 4091.16, 822.3495451448855], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 7" do

    query = "PREFIX foaf:    <http://xmlns.com/foaf/0.1/>\nPREFIX vcard:   <http://www.w3.org/2001/vcard-rdf/3.0#>\n\nCONSTRUCT { ?x  vcard:N _:v .\n            _:v vcard:givenName ?gname .\n            _:v vcard:familyName ?fname }\nWHERE\n  {\n    { ?x foaf:firstname ?gname } UNION  { ?x foaf:givenname   ?gname } .\n    { ?x foaf:surname   ?fname } UNION  { ?x foaf:family_name ?fname } .\n  }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 7")
    IO.inspect([7636.5, 7778.6, 1396.37449131671], label: "was")
    IO.inspect([7515.0, 7636.12, 1283.4149701480037], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 8" do

    query = "PREFIX foaf:    <http://xmlns.com/foaf/0.1/>\nASK  { ?x foaf:name  \"Alice\" ;\n          foaf:mbox  <mailto:alice@work.example> }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 8")
    IO.inspect([1584.0, 1698.97, 405.09049495143677], label: "was")
    IO.inspect([1509.0, 1580.75, 321.6714900329216], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 9" do

    query = "PREFIX a:      <http://www.w3.org/2000/10/annotation-ns#>\nPREFIX dc:     <http://purl.org/dc/elements/1.1/>\nPREFIX xsd:    <http://www.w3.org/2001/XMLSchema#>\n\nSELECT ?annot\nWHERE { ?annot  a:annotates  <http://www.w3.org/TR/rdf-sparql-query/> .\n        ?annot  dc:date      ?date .\n        FILTER ( ?date > \"2005-01-01T00:00:00Z\"^^xsd:dateTime ) }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 9")
    IO.inspect([3942.0, 4203.39, 1033.296713388754], label: "was")
    IO.inspect([4126.0, 4724.52, 2257.8446203403814], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

  @tag :generated_bench
  test "bench: SELECT 10" do

    query = "PREFIX foaf: <http://xmlns.com/foaf/0.1/>\nPREFIX dc:   <http://purl.org/dc/elements/1.1/>\nPREFIX xsd:   <http://www.w3.org/2001/XMLSchema#>\nSELECT ?name\n  WHERE { ?x foaf:givenName  ?givenName .\n          OPTIONAL { ?x dc:date ?date } .\n          FILTER ( bound(?date) ) }"
    bench = fn -> query |> TestHelper.parse end
    bench_times = Tester.Generator.benchmark(bench, 100, false)

    IO.puts("bench: SELECT 10")
    IO.inspect([3495.0, 3760.52, 801.4441649921723], label: "was")
    IO.inspect([3307.0, 3810.83, 976.1476123517384], label: "was with warmup")
    IO.inspect(bench_times, label: "now")

    assert true
  end

end
