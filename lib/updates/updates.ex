defmodule Updates do
  alias Updates.QueryAnalyzer.Iri
  require Logger
  require ALog

  @spec quads_for_query(Parser.unparsed_query()) :: Updates.QueryAnalyzer.quad_changes
  def quads_for_query(query) do
    Parser.parse(query)
    |> Enum.filter(&Generator.Result.full_match?/1)
    |> List.first()
    |> Map.get(:match_construct)
    |> List.first()
    |> Updates.QueryAnalyzer.quad_changes(%{
      default_graph:
        Iri.from_iri_string("<http://mu.semte.ch/application>", %{})
    })
  end

  def to_update_queries([]) do
    []
  end

  def to_update_queries([{:insert, insert_quads} | rest]) do
    # TODO DRY into/from Updates.QueryAnalyzer.insert_quads
    options = %{
      default_graph:
        Iri.from_iri_string("<http://mu.semte.ch/application>", %{})
    }

    process_quads_for_update_id = Profiler.start("process_quads_for_update")
    result =
      insert_quads
      |> Acl.process_quads_for_update(Acl.UserGroups.for_use(:write), %{})
      |> Profiler.stop(process_quads_for_update_id)
      |> ALog.di("processed_quads")
      |> (fn {_, quads} -> quads end).()
      |> Updates.QueryAnalyzer.construct_insert_query_from_quads(options)
      |> Regen.result()

    [result | to_update_queries(rest)]
  end

  def printable_insert_query_for_quads(quads) do
    # See Updates.QueryAnalyzer.insert_quads
    options = %{
      default_graph:
        Iri.from_iri_string("<http://mu.semte.ch/application>", %{})
    }

    quads
    # |> consolidate_insert_quads
    # |> dispatch_insert_quads_to_desired_graphs
    |> Updates.QueryAnalyzer.construct_insert_query_from_quads(options)
    |> Regen.result()
  end

  def insert_quads(quads) do
    # TODO: we should get the options back from quads_for_query
    Updates.QueryAnalyzer.insert_quads(
      quads,
      %{
        default_graph:
          Iri.from_iri_string("<http://mu.semte.ch/application>", %{})
      }
    )
  end
end
