alias GraphReasoner.QueryInfo, as: QueryInfo

defmodule QueryInfo do
  defstruct terms_map: %{}

  @type t :: %QueryInfo{terms_map: %{}}

  @doc """
  Yields the terms map.
  """
  def terms_map(%QueryInfo{terms_map: terms_map}) do
    terms_map
  end

  @doc """
  Sets the terms_map to a new value.
  """
  def set_terms_map(query_info, new_terms_map) do
    %{query_info | terms_map: new_terms_map}
  end

  @doc """
  Adds a property to the terms map with given name.  Currently supported names are:
  - :related_paths

  If the info was already known, it is not overwritten.
  """
  @type push_term_info( t ) :: t
  def push_term_info( %QueryInfo{ terms_map: terms_map } = query_info, symbol, section, value ) do
    term_id = ExternalInfo.get(symbol, GraphReasoner, :term_id)
    renamed_term_id = terms_map.term_ids[term_id]

    new_terms_map =
      update_in(
        terms_map[:term_info][renamed_term_id][section],
        fn related_paths ->
          related_paths = related_paths || []
          # Push value if it does not exist
          if Enum.member?(related_paths, value) do
            related_paths
          else
            [value | related_paths]
          end
        end
      )

    %{ query_info | terms_map: new_terms_map }

  end
end
