File.mkdir_p(Path.dirname(JUnitFormatter.get_report_file_path()))
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

defmodule TestHelper do
  alias InterpreterTerms.SymbolMatch, as: Sym
  alias InterpreterTerms.WordMatch, as: Word

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
