defmodule Regen.Constructor do
  @type t ::
          Regen.Processors.Word.t()
          | Regen.Processors.Array.t()
          | Regen.Processors.Choice.t()
          | Regen.Processors.Some.t()
          | Regen.Processors.Many.t()
          | Regen.Processors.Maybe.t()
          | Regen.Processors.Symbol.t()

  @doc """
  Converts a parsed EBNF element to a generator
  """
  def make({:single_quoted_string, word}, state) do
    %Regen.Processors.Word{word: word, state: state}
  end

  def make({:paren_group, elements}, state) do
    %Regen.Processors.Array{elements: elements, state: state}
  end

  def make({:one_of, elements}, state) do
    %Regen.Processors.Choice{options: elements, state: state}
  end

  def make({:maybe_many, [element]}, state) do
    %Regen.Processors.Some{element: element, state: state}
  end

  def make({:one_or_more, [element]}, state) do
    %Regen.Processors.Many{element: element, state: state}
  end

  def make({:maybe, [element]}, state) do
    %Regen.Processors.Maybe{element: element, state: state}
  end

  def make({:symbol, symbol}, state) do
    %Regen.Processors.Symbol{symbol: symbol, state: state}
  end

  def make([spec], state) do
    make(spec, state)
  end

  def make(items, state) when is_list(items) do
    make({:paren_group, items}, state)
  end
end
