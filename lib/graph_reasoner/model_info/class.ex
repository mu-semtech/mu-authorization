alias GraphReasoner.ModelInfo.Class, as: Class
alias GraphReasoner.ModelInfo.Property, as: Property
alias GraphReasoner.ModelInfo, as: ModelInfo

defmodule Class do
  @moduledoc """
  Represents a class in the model definition.
  """

  @type t :: %Class{uri: ModelInfo.uri(), properties: [Property.t()]}
  defstruct uri: "", properties: []
end
