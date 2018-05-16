defmodule Updates do

  def quads_for_query( query ) do
    Parser.parse_query_all( query )
    |> Enum.filter( &Generator.Result.full_match?/1 )
    |> List.first
    |> Map.get( :match_construct )
    |> List.first
    |> Updates.QueryAnalyzer.quads(
      %{ default_graph: Updates.QueryAnalyzer.Iri.from_iri_string( "<http://mu.semte.ch/application>", %{} ) } )
  end

  def insert_quads( quads ) do
    # TODO: we should get hte options back from quads_for_query
    Updates.QueryAnalyzer.insert_quads( quads,
      %{ default_graph: Updates.QueryAnalyzer.Iri.from_iri_string( "<http://mu.semte.ch/application>", %{} ) } )
  end

end
