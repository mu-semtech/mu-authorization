alias GraphReasoner.ModelInfo.Class, as: Class

defmodule Class do
  alias GraphReasoner.ModelInfo.Property, as: Property
  alias GraphReasoner.ModelInfo, as: ModelInfo

  @moduledoc """
  Represents a class in the model definition.
  """

  @type t :: %Class{uri: ModelInfo.uri(), properties: [Property.t()]}
  defstruct uri: "", properties: []
end
