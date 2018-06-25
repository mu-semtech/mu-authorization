defmodule QueryTemplate do
  @moduledoc """
  Returns a regex that can serve as a query template to check if the
  query that was passed is formative the same as another query
  end
  """
  def example_parsed_query do
    "PREFIX foo: <http://example.com/foo> PREFIX bar: <http://example.com/bar> SELECT ?s ?o WHERE { ?s bar:123 ?o . ?s2 rdfs:type ?type ; ?p2 ?o2 , ?o3 .}"
    |> Parser.parse_query_full
  end

  defp flatten_fun([x|r] = arr, acc) do
    Enum.reduce(arr, acc, fn(x, acc) -> flatten_fun(x, acc) end)
  end

  defp flatten_fun(x, acc) do
    [x|acc]
  end

  defp group_fun(x, []) do
    [x]
  end

  defp group_fun(x, [%{type: :const} = first | r] = acc) do
    [x|acc]
  end

  defp group_fun(%{type: type} = x, acc) when type === :const do
    [x|acc]
  end

  defp group_fun(%{type: type} = x, [%{type: type2} = first | r]) do
    [%{type: :regex, regex: first.regex <> x.regex, value: first.value <> " " <> x.value} | r]
  end

  def to_regex_template do
    query = example_parsed_query()
    [queryShell] = query.submatches
    [queryUnit] = queryShell.submatches
    structure = queryUnit.submatches
    |> Enum.map(fn(x) -> to_regex_part(x.symbol, x.submatches) end)
    |> Enum.reduce([], fn(x, acc) -> flatten_fun(x, acc) end)
    |> Enum.filter(fn(x) -> !(x === "") end)
    |> Enum.reverse
    |> Enum.reduce([], fn(x, acc) -> group_fun(x, acc) end)
    |> Enum.reverse

    regex = structure
    |> Enum.map(fn(x) -> x.regex end)
    |> Enum.join
    |> Regex.compile!

    %{
      query: query,
      structure: Enum.map(structure, fn(%{type: type, regex: regex, value: value}) -> %{type: type, regex: Regex.compile!(regex), value: value} end),
      regex: regex
    }
  end

  defp to_regex_block("*") do
    %{type: :regex, regex: "[\\*][\\s]*", value: "*"}
  end

  defp to_regex_block(t) do
    %{type: :regex, regex: "(" <> t <> ")[\\s]*", value: t}
  end

  defp to_regex_part(:Prologue, terms) do
    terms
    |> Enum.map(fn(x) -> to_regex_part(x.symbol, x.submatches) end)
    # |> Enum.join
  end

  defp to_regex_part(:PrefixDecl, terms) do
    p1 = to_regex_block("PREFIX")
    p2 = to_regex_block(String.trim(Enum.at(terms, 1).string))
    p3 = to_regex_block(String.trim(Enum.at(terms, 2).string))
    %{type: :regex, regex: p1.regex <> p2.regex <> p3.regex, value: p1.value <> " " <> p2.value <> " " <> p3.value}
  end

  defp to_regex_part(:SelectQuery, terms) do
    IO.puts "SELECT QUERY"
    terms
    |> Enum.map(fn(x) -> to_regex_part(x.symbol, x.submatches) end)
  end

  defp _select_clause_to_regex(InterpreterTerms.WordMatch, match) do
    to_regex_block(match.word)
  end

  defp _select_clause_to_regex(InterpreterTerms.SymbolMatch, match) do
    to_regex_part(match.symbol, match.submatches)
  end

  defp to_regex_part(:SelectClause, terms) do
    IO.puts "SELECT CLAUSE"
    terms
    |> Enum.map(fn(part) -> _select_clause_to_regex(part.__struct__, part) end)
  end

  defp to_regex_part(:Var, [term]) do
    to_regex_part(term.symbol, term.string)
  end

  defp to_regex_part(:VAR1, var) do
    %{type: :var, regex: "(\\" <> String.trim(var) <> ")[\\s]*", value: var}
  end

  defp pname_or_uri() do
    "[\\s]*(([a-zA-Z0-9]+[:][a-zA-Z0-9]+)|([<][a-zA-Z0-9-_:.\/]+[>]))[\\s]*"
    # "[\\s]*(([a-zA-Z0-9]+[:][a-zA-Z0-9]+)|([<][a-z/.A-Z0-9:-_\\]+[>]))[\\s]*"
  end

  defp to_regex_part(:PrefixedName, [pname]) do
    %{type: :const, regex: pname_or_uri(), value: pname.string}
  end

  defp to_regex_part(:WhereClause, terms) do
    IO.puts "WHERE CLAUSE"
    ggp = Enum.at(terms ,1) # group graph pattern
    ggps = Enum.at(ggp.submatches, 1)
    processed = Enum.map(ggps.submatches, fn(x) -> to_regex_part(x.symbol, x.submatches) end)
    # to_regex_block("WHERE") <> "[{][\\s]*" <> Enum.join(processed) <> "[}][\\s]*"
    [
      to_regex_block("WHERE"),
      %{ type: :regex, regex: "[{][\\s]*", value: "{"},
      processed,
      %{ type: :regex, regex: "[}][\\s]*", value: "}"},
    ]
  end

  defp to_regex_part(:SolutionModifier, terms) do
    IO.puts "SOLUTION MODIFIER"
    ""
  end

  defp to_regex_part(:ValuesClause, terms) do
    IO.puts "VALUES CLAUSE"
    ""
  end

  defp do_to_regex_part(%{__struct__: InterpreterTerms.SymbolMatch} = x) do
    to_regex_part(x.symbol, x.submatches)
  end

  defp do_to_regex_part(%{__struct__: InterpreterTerms.WordMatch, word: "."} = x) do
    %{type: :regex, regex: "[.]?[\\s]*", value: "."}
  end

  defp do_to_regex_part(%{__struct__: InterpreterTerms.WordMatch, word: ";"} = x) do
    %{type: :regex, regex: "[;][\\s]*", value: ";"}
  end

  defp do_to_regex_part(%{__struct__: InterpreterTerms.WordMatch, word: ","} = x) do
    %{type: :regex, regex: "[,][\\s]*", value: ","}
  end

  defp to_regex_part(symbol, terms) do
    IO.inspect symbol
    terms
    |> Enum.map(fn(x) ->  do_to_regex_part(x) end)
    # |> Enum.join
  end

  ## This part is about parameter list extraction

  defp reduce_query_with_structure(%{type: :regex} = part, %{query: query, structure: structure}) do
    new_query = query |> String.replace(part.value, "") |> String.trim
    %{query: new_query, structure: structure}
  end

  defp reduce_query_with_structure(%{type: :const} = part, %{query: query, structure: structure}) do
    new_value = part.regex |> Regex.run(query) |> Enum.at(0) |> String.trim
    new_query = query |> String.replace(new_value, "") |> String.trim
    %{query: new_query, structure: [%{key: part.value, value: new_value} | structure]}
  end

  def extract_param_list(query, structure) do
    Enum.reduce(structure, %{query: query, structure: []}, fn (x, acc) -> reduce_query_with_structure(x, acc) end)
  end

  ## This part will take the passed query and replace the values with those from the param list
end
