alias Acl.GroupSpec.GraphCleanup, as: GraphCleanup
alias Updates.QueryAnalyzer.Types.Quad, as: Quad
alias Updates.QueryAnalyzer.Iri, as: Iri

defmodule Acl.GroupSpec.GraphCleanup do
  defstruct [originating_graph: "http://mu.semte.ch/application"]

  defimpl Acl.GroupSpec.Protocol do
    def accessible?( %GraphCleanup{}, _ ) do
      # We are always accessible, and we don't belong to an access
      # group.
      { :ok, [[]] }
    end

    def process( %GraphCleanup{} = graph_cleanup, _, quads ) do
      GraphCleanup.clean_originating_graph( graph_cleanup, quads )
    end
  end

  def clean_originating_graph( %GraphCleanup{ originating_graph: graph }, quads ) do
    real_graph_iri = "<" <> graph <> ">"

    clean_quads = Enum.reject quads, fn
      ( %Quad{ graph: %Iri{ iri: ^real_graph_iri } } ) -> true
      ( _ ) -> false
    end

    clean_quads
  end

end
