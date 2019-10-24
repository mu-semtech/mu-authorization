defmodule Delta.Config do
  @moduledoc """
  Configuration for the Delta service.  This file describes which
  components should be informed.
  """

  @type target :: String.t()

  @doc """
  Links to each endpoint to which the delta's will be sent.
  Optionally containing ports.
  """
  @spec targets() :: [target]
  def targets do
    [
      # "http://resource/.mu/delta",
      # "http://example:8080/delta"
    ]
  end
end
