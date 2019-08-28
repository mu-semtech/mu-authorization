alias InterpreterTerms.WordMatch, as: Word
alias InterpreterTerms.SymbolMatch, as: Sym

require Manipulators.Basics

defmodule Compat.Modifiers.MergeGraphsForUpdateData do
  @behaviour Compat.QueryManipulator

  @impl Compat.QueryManipulator
  def manipulate(query) do
    case verify_and_extract_quads_not_triples(query) do
      # check we only have quads in our updater
      {:ok, quads_not_triples_list} ->
        # group quads by GRAPH URI
        quads_by_graph_uri =
          quads_not_triples_list
          |> Enum.map(fn %Sym{
                           symbol: :QuadsNotTriples,
                           submatches: [%Word{}, var_or_iri, %Word{}, triples_template, %Word{}]
                         } ->
            {var_or_iri, triples_template}
          end)
          |> Enum.reduce(%{}, fn {var_or_iri, triples_template}, map ->
            Map.update(map, var_or_iri, [triples_template], &[triples_template | &1])
          end)

        # create triples templates
        quads_not_triples =
          quads_by_graph_uri
          |> Map.keys()
          |> Enum.reject(fn key ->
            Enum.empty?(Map.get(quads_by_graph_uri, key))
          end)
          |> Enum.map(fn key ->
            triples_template_list = Map.get(quads_by_graph_uri, key)

            %Sym{
              symbol: :QuadsNotTriples,
              submatches: [
                %Word{word: "GRAPH"},
                key,
                %Word{word: "{"},
                unify_triples_template_list(triples_template_list),
                %Word{word: "}"}
              ]
            }
          end)

        Manipulators.Basics.do_map query, element do
          %Sym{symbol: :Quads} ->
            {:replace_by, %{element | submatches: quads_not_triples}}
        end

      # move quads_not_triples into query
      {:error} ->
        query
    end
  end

  @spec unify_triples_template_list([
          %Sym{symbol: :TriplesTemplate, submatches: [:TriplesSameSubject]}
        ]) :: %Sym{symbol: :TriplesTemplate}
  defp unify_triples_template_list(triples_template_list) do
    triples_template_list
    |> Enum.reduce(fn %Sym{
                        symbol: :TriplesTemplate,
                        submatches: [%Sym{symbol: :TriplesSameSubject} = triples_same_subject]
                      },
                      acc ->
      %Sym{symbol: :TriplesTemplate, submatches: [triples_same_subject, %Word{word: "."}, acc]}
    end)
  end

  @spec verify_and_extract_quads_not_triples(%Sym{}) ::
          {:error}
          | {:ok,
             [
               %Sym{
                 symbol: :QuadsNotTriples,
                 # can't represent the list contains exactly these items
                 submatches: [
                   %Word{}
                   | %Sym{symbol: :VarOrIri}
                   | %Word{}
                   | %Sym{
                       symbol: :TriplesTemplate,
                       submatches: [
                         %Sym{symbol: :TriplesSameSubject}
                       ]
                     }
                 ]
               }
             ]}
  defp verify_and_extract_quads_not_triples(query) do
    extracted_query_info =
      Manipulators.Basics.do_state_map {:no_insert_delete_data, query}, {state, element} do
        %Sym{symbol: :QuadData} ->
          {:continue, {:has_quad_data, []}}

        %Sym{symbol: :QuadsNotTriples} ->
          case state do
            {:has_quad_data, arr} ->
              case element do
                %Sym{
                  symbol: :QuadsNotTriples,
                  submatches: [
                    %Word{},
                    %Sym{symbol: :VarOrIri},
                    %Word{},
                    %Sym{
                      symbol: :TriplesTemplate,
                      submatches: [
                        # TODO should cope with trailing dot as word too
                        %Sym{symbol: :TriplesSameSubject}
                      ]
                    },
                    %Word{}
                  ]
                } ->
                  {:skip, {:has_quad_data, [element | arr]}}

                _ ->
                  {:exit, {:error, :unsupported_quads_not_triples_format, nil}, nil}
              end

            _ ->
              {:exit, {:error, :quads_not_triples_outside_insert_or_delete_data_query}, nil}
          end

        %Sym{symbol: :TriplesTemplate} ->
          {:exit, {:error, :triples_template_not_inside_supported_quads_not_triples}}
      end

    case extracted_query_info do
      {:exit, {:error, _, _}, _} ->
        {:error}

      {:no_insert_delete_data, _query} ->
        {:error}

      {{:has_quad_data, arr}, _} ->
        {:ok, arr}
    end
  end
end
