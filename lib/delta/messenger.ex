defmodule Delta.Messenger do
  require Logger
  require ALog

  @type call_options :: [mu_call_id_trail: String.t()]

  @moduledoc """
  Sends constructed messages to all interested clients.
  """
  @spec inform_clients(Delta.Message.t(), call_options) :: :ok
  def inform_clients(message, options \\ []) do
    # TODO we should create one thread per callee and push messages on
    # there.  As long as the client hasn't shown a sign of life, we
    # don't need to remember the messages indefinitely.  However, once
    # it boots up, we want to keep informing clients on updates in a
    # queued format.  We now push the updates towards all clients in
    # new threads, assuming we will not kill them with too many
    # connections.
    Delta.Config.targets()
    |> ALog.di("Targets to inform")
    |> Enum.map(&spawn(Delta.Messenger, :send_message_to_client, [message, &1, options]))

    :ok
  end

  @doc """
  Sends a single message to a single client.  This method is meant to
  be ran in a separate thread to inform a specific client.  It is
  called from inform_clients.
  """
  @spec send_message_to_client(Delta.Message.t(), Delta.Config.target(), call_options) ::
          :ok | :fail
  def send_message_to_client(message, client_url, options \\ []) do
    # TODO we should try to send the message again with exponential
    # backoff if the sending of the message failed.
    headers = [
      {"Content-Type", "application/json"},
      {"mu-call-scope-id", options[:mu_call_scope_id]},
      {"mu-call-id", Integer.to_string(Enum.random(0..1_000_000_000_000))},
      {"mu-call-id-trail", options[:mu_call_id_trail]}
    ]

    # we expect clients to respond to our request
    options = [recv_timeout: 50_000]

    Logging.EnvLog.log(
      :log_delta_client_communication,
      "Sending message to <#{client_url}>: #{message}"
    )

    case HTTPoison.post(client_url, "#{message}", headers, options) do
      {:ok, _response} ->
        Logging.EnvLog.log(
          :log_delta_client_communication,
          "Sent delta to #{client_url}"
        )

        :ok

      {:error, reason} ->
        Logger.warn(fn -> {"Could not send delta to #{client_url}", [reason: reason]} end)
        :fail
    end
  end
end
