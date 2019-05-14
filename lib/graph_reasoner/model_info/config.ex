alias GraphReasoner.ModelInfo.Class, as: Class
alias GraphReasoner.ModelInfo.Property, as: Property
alias GraphReasoner.ModelInfo

defmodule GraphReasoner.ModelInfo.Config do
  @moduledoc """
  Informs the GraphReasoner about model information in the
  triplestore.
  """

  @doc """
  Yields known classes, their properties, and the targets of those
  properties.
  """
  @spec class_description() :: ModelInfo.t()
  def class_description do
    [
      %Class{
        uri: "http://xmlns.com/foaf/0.1/Agent",
        properties: [
          %Property{
            uri: "http://xmlns.com/foaf/0.1/name",
            targets: [:primitive]
          },
          %Property{
            uri: "http://xmlns.com/foaf/0.1/knows",
            targets: ["http://xmlns.com/foaf/0.1/Agent", "http://xmlns.com/foaf/0.1/Person"]
          },
          %Property{
            uri: "http://mu.semte.ch/vocabularies/ext/has_mailbox",
            targets: ["http://www.semanticdesktop.org/ontologies/2007/03/22/nmo#Mailbox"]
          },
          %Property{
            uri: "http://reference",
            targets: [:uri]
          }
        ]
      },
      %Class{
        uri: "http://www.semanticdesktop.org/ontologies/2007/03/22/nmo#Mailbox",
        properties: [
          %Property{
            uri: "http://xmlns.com/foaf/0.1/name",
            targets: [:primitive]
          }
        ]
      }
    ]
  end
end
