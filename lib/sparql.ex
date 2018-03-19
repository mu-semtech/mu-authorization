defmodule Sparql do
  @moduledoc """
  Documentation for Sparql.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Sparql.hello
      :world

  """
  def hello do
    :world
  end

  def parse(raw_query) do
    raw_query |> tokenize |> do_parse
  end

  def tokenize(raw_query) do
    :"sparql-tokenizer".string(raw_query)
  end

  def do_parse({:ok, tokenized_query, _}) do
    :"sparql-parser".parse(tokenized_query)
  end

  def do_parse({:error, _, _} = error_message) do
    error_message
  end
end
