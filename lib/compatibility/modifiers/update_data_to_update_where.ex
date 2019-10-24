defmodule Compat.Modifiers.UpdateDataToUpdateWhere do
  alias InterpreterTerms.WordMatch, as: Word
  alias InterpreterTerms.SymbolMatch, as: Sym

  require Manipulators.Basics

  @behaviour Compat.QueryManipulator

  @impl Compat.QueryManipulator
  def manipulate(query) do
    case extract_quad_data_and_quads_from_delete_data(query) do
      {:error, _} ->
        query

      {:ok, quad_data, quads} ->
        optionalized_group_graph_pattern =
          quad_data
          |> Manipulator.Transform.quad_data_to_group_graph_pattern()
          |> make_graph_graph_patterns_optional()

        delete_data_to_delete_where_query(query, quads, optionalized_group_graph_pattern)
    end
  end

  defp extract_quad_data_and_quads_from_delete_data(query) do
    # Extracts quads and data from a delete data query or yields
    # {:error, _} tuple when not a delete data query.
    #
    # Returns { :ok, quad_data, quads } on success
    # Returns { :erorr, message_or_query } on failure
    query_detection =
      Manipulators.Basics.do_state_map {:no_delete, query}, {state, element} do
        %Sym{
          symbol: :Update1,
          submatches: [
            %Sym{
              symbol: :DeleteData,
              submatches: [
                %Word{},
                %Word{},
                %Sym{
                  symbol: :QuadData,
                  submatches: [
                    %Word{},
                    quads,
                    %Word{}
                  ]
                } = quad_data
              ]
            }
          ]
        } ->
          {:exit, {:is_delete, quad_data, quads}, nil}
      end

    case query_detection do
      {:no_delete, query} -> {:error, query}
      {:exit, {:is_delete, quad_data, quads}, nil} -> {:ok, quad_data, quads}
    end
  end

  defp make_graph_graph_patterns_optional(query) do
    # Makes all :GraphGraphPattern instances optional.  Assuming
    # wrapping in graphs exists.  If none are found, nothing is
    # converted.
    Manipulators.Basics.do_map query, element do
      %Sym{
        symbol: :GraphGraphPattern,
        submatches: [
          word,
          graph_iri,
          group_graph_pattern
        ]
      } ->
        {:replace_by,
         %Sym{
           symbol: :GraphGraphPattern,
           submatches: [
             word,
             graph_iri,
             %Sym{
               symbol: :GroupGraphPattern,
               submatches: [
                 %Word{word: "{"},
                 %Sym{
                   symbol: :GroupGraphPatternSub,
                   submatches: [
                     %Sym{
                       symbol: :GraphPatternNotTriples,
                       submatches: [
                         %Sym{
                           symbol: :OptionalGraphPattern,
                           submatches: [
                             %Word{word: "OPTIONAL"},
                             group_graph_pattern
                           ]
                         }
                       ]
                     }
                   ]
                 },
                 %Word{word: "}"}
               ]
             }
           ]
         }}
    end
  end

  defp delete_data_to_delete_where_query(query, quads, group_graph_pattern) do
    # Converts a :DeleteData query into a :DeleteWhere query, assuming
    # the necessary bits to alter are supplied.  Assumes extraction of
    # quads and conversion to group_graph_pattern has happened before.
    Manipulators.Basics.do_map query, element do
      %Sym{symbol: :DeleteData} ->
        {:replace_by,
         %Sym{
           symbol: :Modify,
           submatches: [
             %Sym{
               symbol: :DeleteClause,
               submatches: [
                 %Word{word: "DELETE"},
                 %Sym{
                   symbol: :QuadPattern,
                   submatches: [
                     %Word{word: "{"},
                     quads,
                     %Word{word: "}"}
                   ]
                 }
               ]
             },
             %Word{word: "WHERE"},
             group_graph_pattern
           ]
         }}
    end
  end
end
