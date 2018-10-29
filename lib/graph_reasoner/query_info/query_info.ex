alias GraphReasoner.QueryInfo, as: QueryInfo

defmodule GraphReasoner.QueryInfo do
  defstruct [terms_map: %{}]

  @doc """
  Yields the terms map.
  """
  def terms_map( %QueryInfo{ terms_map: terms_map } ) do
    terms_map
  end

  @doc """
  Sets the terms_map to a new value.
  """
  def set_terms_map( query_info, new_terms_map ) do
    %{ query_info | terms_map: new_terms_map }
  end
end
