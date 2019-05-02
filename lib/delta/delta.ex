alias Updates.QueryAnalyzer.Types.Quad, as: Quad

defmodule Delta do
  require Logger
  require ALog

  @type insert_type :: :update | :delete
  @type delta :: [{insert_type, [Quad.t()]}]

  @moduledoc """
  This service consumes altered triples and sends them to interested
  clients.  It runs in a separate thread and will always run *after*
  the response has been supplied to the client.
  """

  @doc """
  Publishes the updated quads.  The array is expected to contain
  tuples of form {insert_type, quads} in which insert_type is one of
  :insert or :delete.
  """
  @spec publish_updates(delta, [any], String.t()) :: delta
  def publish_updates(delta, authorization_groups, origin) do
    delta
    |> Delta.Message.construct(authorization_groups, origin)
    |> Logging.EnvLog.inspect(:log_delta_messages, label: "Constructed body for clients")
    |> Delta.Messenger.inform_clients()

    delta
  end
end
