alias Updates.QueryAnalyzer.Types.Quad, as: Quad

defmodule Delta.Message do
  @moduledoc """
  Contains code to construct the correct messenges for informing
  clients.
  """

  @typedoc """
  Type of the messages which can be sent to a client.  Currently, this
  is a binary string.
  """
  @type t :: String.t

  @doc """
  Constructs a new message which can be sent to the clients based on a
  quad delta.
  """
  @spec construct( Delta.delta ) :: Delta.Message.t
  def construct( delta ) do
    json_model = %{
      "changeSets" => Enum.map( delta, &convert_delta_item/1 )
    }
    Poison.encode!( json_model )
  end

  defp convert_delta_item( { :insert, quads } ) do
    %{ "insert" => Enum.map( quads, &convert_quad/1 ) }
  end
  defp convert_delta_item( { :delete, quads } ) do
    %{ "delete" => Enum.map( quads, &convert_quad/1 ) }
  end

  defp convert_quad( %Quad{ subject: subject, predicate: predicate, object: object } ) do
    [s, p, o] =
      Enum.map(
        [subject,predicate,object],
        &Updates.QueryAnalyzer.P.to_sparql_result_value/1 )

    %{"subject" => s, "predicate" => p, "object" => o}
  end
end
