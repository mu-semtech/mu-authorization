File.mkdir_p(Path.dirname(JUnitFormatter.get_report_file_path()))
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

defmodule TestHelper do
  use EbnfParser.Sparql
  alias InterpreterTerms.SymbolMatch, as: Sym
  alias InterpreterTerms.WordMatch, as: Word

  # TODO cleanup
  defp new_parse_query(query, parsers) do
    rule_name = :Sparql
    {parser, _} = Map.get(parsers, rule_name)

    EbnfParser.ParseProtocol.parse(parser, parsers, query |> String.graphemes())
    |> Enum.sort_by(&Generator.Result.length/1, &>=/2)
    |> List.first()
  end

  def parse(query) do
    # parsers = parsers
    [sub|_x] = new_parse_query(query, parsers()).match_construct
    %InterpreterTerms.SymbolMatch{symbol: :Sparql, submatches: [sub], string: sub.string}
  end

  def match_ignore_whitespace_and_string(%Sym{symbol: s1, submatches: m1}, %Sym{
        symbol: s2,
        submatches: m2
      })
      when is_list(m1) and is_list(m2) do
    if s1 !== s2 do
      false
    else
      if length(m1) !== length(m2) do
        false
      else
        Enum.zip(m1, m2) |> Enum.all?(fn {x, y} -> match_ignore_whitespace_and_string(x, y) end)
      end
    end
  end

  def match_ignore_whitespace_and_string(%Sym{symbol: s1, submatches: m1}, %Sym{
        symbol: s2,
        submatches: m2
      }) do
    s1 == s2 and m1 == m2
  end

  def match_ignore_whitespace_and_string(%Word{word: w1}, %Word{word: w2}) do
    w1 |> String.downcase() == w2 |> String.downcase()
  end

  def match_ignore_whitespace_and_string(_x, _y) do
    false
  end
end
