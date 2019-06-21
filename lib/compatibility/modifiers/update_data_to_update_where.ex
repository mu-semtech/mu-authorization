alias(InterpreterTerms.WordMatch, as: Word)
alias InterpreterTerms.SymbolMatch, as: Sym

require Manipulators.Basics

defmodule Compat.Modifiers.UpdateDataToUpdateWhere do
  @behaviour Compat.QueryManipulator

  @impl Compat.QueryManipulator
  def manipulate(query) do
    delete_quad_data =
      Manipulators.Basics.do_state_map {:no_delete, query}, {state, element} do
        %Sym{
          symbol: :Update1,
          submatches: [
            %Sym{
              symbol: :DeleteData,
              submatches: [
                %Word{},
                %Word{},
                %Sym{symbol: :QuadData} = quad_data
              ]
            }
          ]
        } ->
          {:exit, {:is_delete, quad_data}, nil}
      end

    case delete_quad_data do
      {:no_delete, query} ->
        IO.puts("Not a delete query")
        query

      {:exit, {:is_delete, quad_data}, nil} ->
        IO.puts("A delete query!")
        IO.puts("Delete quad data")
        Regen.result(quad_data, :QuadData)

        optionalized_group_graph_pattern =
          quad_data
          |> Manipulator.Transform.quad_data_to_group_graph_pattern()
          |> make_graph_graph_patterns_optional()

        %Sym{symbol: :QuadData, submatches: [%Word{}, quads, %Word{}]} = quad_data

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
                 optionalized_group_graph_pattern
               ]
             }}
        end
    end
  end

  defp make_graph_graph_patterns_optional(query) do
    Manipulators.Basics.do_map query, element do
      %Sym{
        symbol: :GraphGraphPattern,
        submatches: [
          word,
          graph_iri,
          group_graph_pattern
        ]
      } ->
        IO.inspect(Regen.result(group_graph_pattern, :GroupGraphPattern),
          label: "GroupGraphPattern used for updating"
        )

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
end
