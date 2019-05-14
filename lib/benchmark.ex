defmodule Benchmark do
  import ExProf.Macro

  def measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end

  @doc "analyze with profile macro"
  def do_analyze do
    profile do
      run_test()
    end
  end

  @doc "get analysis records and sum them up"
  def run do
    {records, _block_result} = do_analyze()
    total_percent = Enum.reduce(records, 0.0, &(&1.percent + &2))
    IO.inspect("total = #{total_percent}")
  end

  def run_fprof do
    :fprof.apply(&run_test/0, [])
    :fprof.profile()
    :fprof.analyse()
  end

  def run_test do
    query = "PREFIX nmo: <http://oscaf.sourceforge.net/nmo.html#>
    PREFIX toezicht: <http://mu.semte.ch/vocabularies/ext/supervision/>
    PREFIX validation: <http://mu.semte.ch/vocabularies/validation/>
    PREFIX bbcdr: <http://mu.semte.ch/vocabularies/ext/bbcdr/>
    PREFIX export: <http://mu.semte.ch/vocabularies/ext/export/>
    PREFIX dbpedia: <http://dbpedia.org/ontology/>
    PREFIX schema: <http://schema.org/>
    PREFIX nie: <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#>
    PREFIX nfo: <http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#>
    PREFIX pav: <http://purl.org/pav/>
    PREFIX nao: <http://www.semanticdesktop.org/ontologies/2007/08/15/nao#>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX regorg: <https://www.w3.org/ns/regorg#>
    PREFIX prov: <http://www.w3.org/ns/prov#>
    PREFIX org: <http://www.w3.org/ns/org#>
    PREFIX person: <http://www.w3.org/ns/person#>
    PREFIX adms: <http://www.w3.org/ns/adms#>
    PREFIX dul: <http://www.ontologydesignpatterns.org/ont/dul/DUL.owl#>
    PREFIX cpsv: <http://purl.org/vocab/cpsv#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX m8g: <http://data.europa.eu/m8g/>
    PREFIX eli: <http://data.europa.eu/eli/ontology#>
    PREFIX generiek: <http://data.vlaanderen.be/ns/generiek#>
    PREFIX persoon: <http://data.vlaanderen.be/ns/persoon#>
    PREFIX mandaat: <http://data.vlaanderen.be/ns/mandaat#>
    PREFIX besluit: <http://data.vlaanderen.be/ns/besluit#>
    PREFIX tmp: <http://mu.semte.ch/vocabularies/tmp/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX rm: <http://mu.semte.ch/vocabularies/logical-delete/>
    PREFIX typedLiterals: <http://mu.semte.ch/vocabularies/typed-literals/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
    PREFIX app: <http://mu.semte.ch/app/>
    PREFIX owl: <http://www.w3.org/2002/07/owl#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    INSERT {
    GRAPH <http://mu.semte.ch/application> {
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:created ?gensym0.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:modified ?gensym1.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> nmo:sentDate ?gensym2.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:string ?gensym3.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:description ?gensym4.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> ext:remark ?gensym5.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:temporalCoverage ?gensym6.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:businessIdentifier ?gensym7.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:businessName ?gensym8.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:nomenclature ?gensym9.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:dateOfEntryIntoForce ?gensym10.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:endDate ?gensym11.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:sessionDate ?gensym12.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:isModification ?gensym13.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:hasExtraTaxRates ?gensym14.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:agendaItemCount ?gensym15.
    }
    } WHERE {
    GRAPH <http://mu.semte.ch/application> {
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:created ?gensym0.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:modified ?gensym1.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> nmo:sentDate ?gensym2.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:string ?gensym3.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:description ?gensym4.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> ext:remark ?gensym5.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:temporalCoverage ?gensym6.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:businessIdentifier ?gensym7.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:businessName ?gensym8.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:nomenclature ?gensym9.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:dateOfEntryIntoForce ?gensym10.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:endDate ?gensym11.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:sessionDate ?gensym12.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:isModification ?gensym13.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:hasExtraTaxRates ?gensym14.
    }
    OPTIONAL {     <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:agendaItemCount ?gensym15.
    }
    }
    };
    INSERT DATA
    {
    GRAPH <http://mu.semte.ch/application> {
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:created \"2018-05-28T12:42:50.291Z\"^^xsd:dateTime.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> dct:modified \"2018-05-28T12:52:35.917Z\"^^xsd:dateTime.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:sessionDate \"2018-05-05\"^^xsd:dateTime.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:isModification \"true\"^^typedLiterals:boolean.
    <http://data.lblod.info/inzendingen-voor-toezicht/5B0BF9583D5ABD0008000001> toezicht:hasExtraTaxRates \"false\"^^typedLiterals:boolean.
    }
    }"

    query
    |> Parser.parse_query_full()
    |> Updates.QueryAnalyzer.quads(%{
      default_graph:
        Updates.QueryAnalyzer.Iri.from_iri_string("<http://mu.semte.ch/application>", %{})
    })
  end
end
