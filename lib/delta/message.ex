defmodule Delta.Message do
  alias Updates.QueryAnalyzer.Types.Quad, as: Quad
  alias SparqlServer.Router.AccessGroupSupport, as: AccessGroupSupport

  @moduledoc """
  Contains code to construct the correct messenges for informing
  clients.
  """

  @typedoc """
  Type of the messages which can be sent to a client.  Currently, this
  is a binary string.
  """
  @type t :: String.t()

  @doc """
  Constructs a new message which can be sent to the clients based on a
  quad delta.
  """
  @spec construct(Delta.delta(), AccessGroupSupport.decoded_json_access_groups(), String.t(), String.t()) ::
          Delta.Message.t()
  def construct(delta, access_groups, origin, call_scope) do
    # TODO we should include the current access rigths and an
    # identifier for the originating service.  This would help
    # services ignore content which came from their end and would
    # allow services to perform updates in the name of a specific
    # user.

    json_model = %{
      "changeSets" =>
        Enum.map(delta, fn delta_item ->
          delta_item
          |> convert_delta_item
          |> add_allowed_groups(access_groups)
          |> add_origin(origin)
          |> add_call_scope(call_scope)
        end)
    }

    Poison.encode!(json_model)
  end

  defp convert_delta_item({:insert, quads}) do
    %{"insert" => Enum.map(quads, &convert_quad/1)}
  end

  defp convert_delta_item({:delete, quads}) do
    %{"delete" => Enum.map(quads, &convert_quad/1)}
  end

  @spec add_allowed_groups(Poison.Decoder.t(), AccessGroupSupport.decoded_json_access_groups()) ::
          Poison.Decoder.t()
  defp add_allowed_groups(map, :sudo) do
    Map.put(map, "allowedGroups", "sudo")
  end

  defp add_allowed_groups(map, access_groups) do
    json_access_groups = AccessGroupSupport.encode_json_access_groups(access_groups)
    Map.put(map, "allowedGroups", json_access_groups)
  end

  defp add_origin(map, origin) do
    Map.put(map, "origin", origin)
  end

  defp add_call_scope(map, call_scope) do
    Map.put(map, "call-scope", call_scope)
  end

  defp convert_quad(%Quad{graph: graph, subject: subject, predicate: predicate, object: object}) do
    [g, s, p, o] =
      Enum.map(
        [graph, subject, predicate, object],
        &Updates.QueryAnalyzer.P.to_sparql_result_value/1
      )

    %{"graph" => g, "subject" => s, "predicate" => p, "object" => o}
  end
end
