alias GraphReasoner.ModelInfo.Config, as: Config
alias GraphReasoner.ModelInfo.Class, as: Class

defmodule GraphReasoner.ModelInfo do
  @moduledoc """
  Stores information about the model in the triplestore which the
  optimizer can use to better understand queries.

  This module uses GraphReasoner.ModelInfo.Config to determine the
  configuration of the semantic model which is used as the base source
  of truth for retrieving information.
  """

  @type uri :: String.t()

  @doc """
  Yields an array of all classes that are known in by the
  class_description configuration.
  """
  def all_classes do
    Config.class_description()
    |> Enum.flat_map(fn %Class{uri: uri, properties: properties} ->
      property_target_types =
        properties
        |> Enum.flat_map(& &1.targets)
        |> Enum.filter(&String.valid?/1)

      [uri | property_target_types]
    end)
    |> Enum.dedup()
  end

  @doc """
  Yields the domain of a predicate
  """
  @spec predicate_domain(uri) :: [uri]
  def predicate_domain(predicate) do
    Config.class_description()
    |> Enum.filter(fn class ->
      class.properties
      |> Enum.map(& &1.uri)
      |> Enum.member?(predicate)
    end)
    |> Enum.map(& &1.uri)
  end

  @doc """
  Yields the range of a predicate
  """
  @spec predicate_range(String.t()) :: [String.t()]
  def predicate_range(predicate) do
    Config.class_description()
    |> Enum.flat_map( & &1.properties )
    |> Enum.filter( &( &1.uri == predicate ) )
    |> Enum.flat_map( & &1.targets )
    |> Enum.dedup
  end

  
end
