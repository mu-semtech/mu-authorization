alias GraphReasoner.ModelInfo.Property, as: Property

defmodule Property do
  alias GraphReasoner.ModelInfo, as: ModelInfo

  @moduledoc """
  Represents the specification for a specific property.  Allows
  setting the uri of the property and the targeted range.
  """

  @type t :: %Property{uri: ModelInfo.uri(), targets: [property_target]}

  @type uri_like :: ModelInfo.uri() | :uri
  @type primitive :: :primitive

  @type property_target :: uri_like | primitive

  defstruct uri: "", targets: []
end
