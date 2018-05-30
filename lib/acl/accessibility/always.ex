alias Acl.Accessibility.Always, as: AlwaysAccessible

defmodule AlwaysAccessible do
  defstruct []

  @moduledoc """
  Represents the graph constraint for content that is always
  accessible.  Regardless of the user, these contents can always be
  consumed (whether this is for reading, or for writing is handled
  separately.)
  """

  defimpl Acl.Accessibility.Protocol do
    @doc """
    This element is always accessible.  There is no need to perform
    any checks.  Furthermore, as this is always accessible, there is
    no need to yield any specific parameters indicating a scope.
    """
    def accessible?( %AlwaysAccessible{}, _graph_spec, _request ) do
      {:ok, [[]]}
    end
  end

end
