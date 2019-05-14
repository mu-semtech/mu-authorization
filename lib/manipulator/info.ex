defmodule Manipulators.Info do
  require Manipulators.Basics

  @moduledoc """
  Helpers to extract common information from a query.
  """

  @doc """
  Extracts prefixes and base from the supplied query and yields them as a map.
  """
  def prologue_map(query) do
    Manipulators.Basics.do_state_map {%{}, query}, {state, elt} do
      :Prologue ->
        {:exit, Updates.QueryAnalyzer.import_prologue(elt, state), nil}
    end
    |> elem(1)
  end
end
