defmodule GraphReasoner.Support.TermsMap do

  """
  Adds a property to the terms map with given name.  Currently supported names are:
  - :related_paths
  """
  def push_term_info( terms_map, symbol, section, value ) do
    term_id = ExternalInfo.get( symbol, GraphReasoner, :term_id )
    renamed_term_id = terms_map.term_ids[term_id]

    new_terms_map =
      update_in(
        terms_map[:term_info][renamed_term_id][section],
        fn (related_paths) ->
          [ value | (related_paths || []) ]
        end )

    new_terms_map
  end

end
