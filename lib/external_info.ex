defmodule ExternalInfo do
  @moduledoc """
  Helper code to work with external information.  This ensures it's
  easy to add specifically scoped data to structs.

  In order to use the methods offered by this module, the struct must
  have an ':external' property containing a map.

  The most common use is to use ExternalInfo.get/3 and
  ExternalInfo.put/4 to retrieve and set named variables within your
  realm.  If there is only one variable in your realm, you may use
  ExternalInfo.get/2 and ExternalInfo.put/3, as if the item itself
  were a map.

  NOTE: The methods offered here can be used as helpers which behave
  similar to a Map.  We don't reuse the Map interface because it would
  be difficult or impossible to implement.  Perhaps a future trick can
  help.
  """

  @doc """
  Retrieves the full contents for an external realm.
  """
  def get(element, realm) do
    Map.get(element.external, realm)
  end

  @doc """
  Puts the full contents of an external realm.
  """
  def put(element, realm, value) do
    %{element | external: Map.put(element.external, realm, value)}
  end

  @doc """
  Retrieves a single variable's value from an external realm.
  """
  def get(element, realm, name) do
    case get(element, realm) do
      nil -> nil
      item -> Map.get(item, name)
    end
  end

  @doc """
  Sets a single variable's value from an external realm.
  """
  def put(element, realm, name, value) do
    realm_map = get(element, realm) || %{}
    new_realm_map = Map.put(realm_map, name, value)

    put(element, realm, new_realm_map)
  end

  @doc """
  Returns truethy iff the variable with name <name> has been set in
  realm <realm> at some point.
  """
  def has_var?(element, realm, name) do
    realm_map = get(element, realm) || %{}

    Map.has_key?(realm_map, name)
  end
end
