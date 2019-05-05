alias GraphReasoner.QueryInfo.TermInfo

defmodule TermInfo do
  @moduledoc """
  TermInfo contains information we know about a specific term.  It
  consists of constraints which must hold for this particular term.
  """

  @type t :: %TermInfo{}

  defstruct type_constraints: [], value_constraints: []
end
