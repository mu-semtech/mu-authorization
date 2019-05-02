alias GraphReasoner.QueryInfo, as: QueryInfo

# A strategy for defining access
#
# We will attach graph constraints to the predicates
#
# We will assume the WHERE block has been converted into simple triple
# statements.
#
# 1. Derive types for variables
# 2. Derive types for subjects (already known if that is a variable)
# 3. Derive types for objects (already known if that is a variable)
#
# 3. Attach graphs to predicates based on types and predicate
#
# later: 1 and 2 will be combined so we can iterate on the gained knowledge.
# later: 2 will also attach types to the object type of the triple

defmodule QueryInfo do
  defstruct terms_map: %{}

  @type t :: %QueryInfo{terms_map: terms_map}
  @type terms_map :: %{
          term_ids_index: integer(),
          term_info_index: integer(),
          term_ids: %{optional(number) => number},
          term_info: %{optional(number) => %{optional(atom) => any}}
        }

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
  @spec push_term_info(t, any, atom(), any) :: t
  def push_term_info(%QueryInfo{terms_map: terms_map} = query_info, symbol, section, value) do
    new_terms_map =
      update_in(
        terms_map[:term_info][renamed_term_id(query_info, symbol)][section],
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

    %{query_info | terms_map: new_terms_map}
  end

  @doc """
  Retrieves scoped subject info for a term as known by the QueryInfo.
  """
  @spec get_term_info(t, any, atom) :: any
  def get_term_info(query_info, symbol, section) do
    query_info.terms_map[:term_info][renamed_term_id(query_info, symbol)][section]
  end

  @doc """
  Retrieves scoped subject info for a term as known by the QueryInfo
  identified by its id.
  """
  @spec get_term_info_by_id(t, number, atom) :: any
  def get_term_info_by_id(query_info, term_id, section) do
    query_info.terms_map[:term_info][term_id][section]
  end

  @doc """
  Sets scoped subject info for a term as known by the QueryInfo
  identified by its id.
  """
  @spec set_term_info_by_id(t, number, atom, any) :: t
  def set_term_info_by_id(query_info, term_id, section, value) do
    terms_map = query_info.terms_map
    new_terms_map =
      update_in(
        terms_map[:term_info][term_id][section],
        fn (_old) -> value end )
    %{ query_info | terms_map: new_terms_map }
  end

  @spec renamed_term_id(t, any) :: number
  defp renamed_term_id(%QueryInfo{terms_map: terms_map}, symbol) do
    term_id = ExternalInfo.get(symbol, GraphReasoner, :term_id)
    terms_map.term_ids[term_id]
  end
end
