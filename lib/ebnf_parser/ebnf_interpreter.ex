defmodule EbnfInterpreter do
  @moduledoc """
  Most eager interpreter of syntax which we could implement.  This
  consumes all content which was available and tries to match as much
  content as possible.
  """

  def char_for_code({:character, char}) do
    char
  end

  def char_for_code({:hex_character, codepoint}) do
    <<codepoint::utf8>>
  end

  @doc """
  ## Examples
  Iex> EbnfInterpreter.t_ep( "FOO" )
  ["F", "O", "O" ]
  """
  def t_ep(str) do
    String.codepoints(str)
  end

  def generate_all_options(generator, results \\ []) do
    case EbnfParser.Generator.emit(generator) do
      {:ok, new_state, answer} ->
        generate_all_options(new_state, [answer | results])

      _ ->
        results
    end
  end

  def match_named_rule(rule_name, chars, syntax) do
    # # Try to match a named rule.  This needs to update matched_rule_info
    # eagerly_match_rule( chars, syntax, {:symbol, rule_name}, %{terminal: false} )

    # Try to match a named rule.  This needs to update matched_rule_info
    # make_generator( { :symbol, rule_name }, chars, syntax, %{terminal: false} )
    # |> emit

    rule = {:symbol, rule_name}
    state = %Generator.State{chars: chars, syntax: syntax}

    EbnfParser.GeneratorConstructor.dispatch_generation(rule, state)
    |> EbnfParser.Generator.emit()
  end

  def match_sparql_rule(rule_name, string, include_generator \\ false) do
    response = match_named_rule(rule_name, String.codepoints(string), Parser.parse_sparql())

    if include_generator do
      response
    else
      case response do
        {:ok, _, result} -> result
        _ -> {:fail}
      end
    end
  end
end
