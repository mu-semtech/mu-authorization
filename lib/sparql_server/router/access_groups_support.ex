defmodule SparqlServer.Router.AccessGroupSupport do
  require Logger
  require ALog

  @moduledoc """
  Provides supporting functions for working with the encoding and
  decoding of access groups with respect to the connection.
  """

  @doc """
  Encodes hte JSON access groups in such a way that they can be placed
  on the connection.
  """
  def encode_json_access_groups( access_groups ) do
    access_groups
    |> Enum.map( fn ({name, variables}) ->
      %{ "name" => name, "variables" => variables }
    end)
    |> Poison.encode!
  end

  @doc """
  Retrieves the JSON access groups from the connection and converts
  them into a format which can be used internally.
  """
  def decode_json_access_groups( json_string ) do
    json_string
    |> Poison.decode!
    |> Enum.map( fn (%{"name" => name, "variables" => variables}) -> {name, variables} end )
  end

  @doc """
  Calculates the access groups for the given connection and pushes
  them on the connection itself.
  """
  def calculate_access_groups( conn ) do
    access_groups = get_access_groups( conn )

    conn = if access_groups != :sudo do
      Plug.Conn.put_resp_header(
        conn,
        "mu-auth-allowed-groups",
        encode_json_access_groups( access_groups ) )
    else
      conn
    end

    ALog.ii access_groups, "Access groups"

    { conn, access_groups }
  end

  ### Calculates the access groups from the connection, yielding the
  ### access groups in a way consumable by calculate_access_groups.
  defp get_access_groups( conn ) do
    access_groups = Plug.Conn.get_req_header( conn, "mu-auth-allowed-groups" )
    is_sudo = not Enum.empty?( Plug.Conn.get_req_header( conn, "mu-auth-sudo" ) )

    cond do
      is_sudo -> :sudo
      Enum.empty?( access_groups ) ->
        Acl.UserGroups.Config.user_groups
        |> Acl.user_authorization_groups( conn )
        |> ALog.di( "Fresh authorization groups" )
      true ->
        access_groups
        |> List.first
        |> decode_json_access_groups
        |> ALog.di( "Decoded authorization groups" )
    end
  end


  @doc """
  Stores the access groups on the connection
  """
  def put_access_groups( conn, authorization_groups ) do
    Plug.Conn.put_resp_header( conn, "mu-auth-used-groups", encode_json_access_groups(authorization_groups) )
  end

end
