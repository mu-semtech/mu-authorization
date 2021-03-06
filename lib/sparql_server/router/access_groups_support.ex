defmodule SparqlServer.Router.AccessGroupSupport do
  require Logger
  require ALog

  @opaque decoded_json_access_groups :: Acl.allowed_groups
  @opaque decoded_json_access_group :: Acl.allowed_group

  @moduledoc """
  Provides supporting functions for working with the encoding and
  decoding of access groups with respect to the connection.
  """

  @doc """
  Encodes the JSON access groups in such a way that they can be placed
  on the connection.
  """
  @spec encode_json_access_groups(decoded_json_access_groups) :: String.t()
  def encode_json_access_groups(access_groups) do
    access_groups
    |> poisonize_access_groups_info
    |> Poison.encode!()
  end

  @spec poisonize_access_groups_info(decoded_json_access_groups) :: Poison.Parser.t()
  def poisonize_access_groups_info(access_groups) do
    access_groups
    |> Enum.map(fn {name, variables} ->
      %{"name" => name, "variables" => variables}
    end)
  end

  @doc """
  Retrieves the JSON access groups from the connection and converts
  them into a format which can be used internally.
  """
  @spec decode_json_access_groups(String.t()) :: decoded_json_access_groups
  def decode_json_access_groups(json_string) do
    json_string
    |> Poison.decode!()
    |> Enum.map(fn %{"name" => name, "variables" => variables} -> {name, variables} end)
  end

  @doc """
  Calculates the access groups for the given connection and pushes
  them on the connection itself.
  """
  @spec calculate_access_groups(Plug.Conn.t()) :: {Plug.Conn.t(), decoded_json_access_groups}
  def calculate_access_groups(conn) do
    access_groups = get_access_groups(conn)

    Logging.EnvLog.inspect(access_groups, :log_access_rights, label: "Received access rights")

    conn =
      if access_groups != :sudo do
        json_encoded_access_groups = encode_json_access_groups(access_groups)

        Plug.Conn.put_resp_header(
          conn,
          "mu-auth-allowed-groups",
          json_encoded_access_groups
        )
      else
        conn
      end

    {conn, access_groups}
  end

  ### Calculates the access groups from the connection, yielding the
  ### access groups in a way consumable by calculate_access_groups.
  @spec get_access_groups(Plug.Conn.t()) :: decoded_json_access_groups
  defp get_access_groups(conn) do
    access_groups = Plug.Conn.get_req_header(conn, "mu-auth-allowed-groups")
    has_sudo_header = not Enum.empty?(Plug.Conn.get_req_header(conn, "mu-auth-sudo"))

    cond do
      has_sudo_header ->
        :sudo

      match?(["sudo"], access_groups) ->
        # We send out "sudo" as Delta contents for changes received
        # through a sudo delta.  This case lets us read in the
        # contents we've sent out transparantly making services which
        # received sudo delta's sudo services.

        # TODO: determine desired effects for passing along sudo
        # rights.
        :sudo

      Enum.empty?(access_groups) ->
        Acl.UserGroups.Config.user_groups()
        |> Acl.user_authorization_groups(conn)
        |> ALog.di("Fresh authorization groups")

      true ->
        access_groups
        |> List.first()
        |> decode_json_access_groups
        |> ALog.di("Decoded authorization groups")
    end
  end

  @doc """
  Stores the access groups on the connection
  """
  def put_access_groups(conn, authorization_groups) do
    Plug.Conn.put_resp_header(
      conn,
      "mu-auth-used-groups",
      encode_json_access_groups(authorization_groups)
    )
  end
end
