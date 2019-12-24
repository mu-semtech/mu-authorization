defmodule Regen.Result do
  def all(generator, emitter \\ &Regen.Protocol.emit/1, results \\ []) do
    case emitter.(generator) do
      {:ok, new_generator, new_result} ->
        all(new_generator, emitter, [new_result | results])

      {_} ->
        Enum.reverse(results)
    end
  end

  @spec as_sparql(Regen.Status.t(), map()) :: Parser.unparsed_query()
  def as_sparql(%Regen.Status{produced_content: arr}, options \\ %{}) do
    as_sparql_p("", Enum.reverse(arr), ensure_basic_options(options))
  end

  defp as_sparql_p(base, ["{" | rest], %{spaces: spaces} = options) do
    new_content =
      base <>
        "\n" <>
        n_spaces(spaces) <>
        "{" <>
        "\n" <>
        n_spaces(spaces + 2)

    as_sparql_p(new_content, rest, %{options | spaces: spaces + 2})
  end

  defp as_sparql_p(base, ["}" | rest], %{spaces: spaces} = options) do
    new_content =
      base <>
        "\n" <>
        n_spaces(spaces - 2) <>
        "}" <>
        "\n" <>
        n_spaces(spaces - 2)

    as_sparql_p(new_content, rest, %{options | spaces: spaces - 2})
  end

  defp as_sparql_p(base, ["." | rest], %{spaces: spaces} = options) do
    new_content =
      base <>
        "." <>
        "\n" <>
        n_spaces(spaces)

    as_sparql_p(new_content, rest, options)
  end

  defp as_sparql_p(base, [word | rest], options) do
    new_content =
      base <>
        word <> " "

    as_sparql_p(new_content, rest, options)
  end

  defp as_sparql_p(base, [], _) do
    base
  end

  defp ensure_basic_options(options) do
    if Map.has_key?(options, :spaces) do
      options
    else
      Map.put(options, :spaces, 0)
    end
  end

  defp n_spaces(n) do
    if n > 0 do
      " " <> n_spaces(n - 1)
    else
      ""
    end
  end
end
