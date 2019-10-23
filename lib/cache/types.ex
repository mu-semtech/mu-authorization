alias Updates.QueryAnalyzer.Iri, as: Iri

defmodule Cache.Types do
  require Logger
  require ALog
  use GenServer

  @moduledoc """
    The use of iri is expected to be a string surrounded with < and >.
  """

  ### GenServer API
  @doc """
    GenServer.init/1 callback
  """
  def init(state), do: {:ok, state}

  @doc """
    GenServer.handle_call/3 callback
  """
  def handle_call(:dequeue, _from, [value | state]) do
    {:reply, value, state}
  end

  @doc """
    Pushes the supplied types to the types of the given URI.
  """
  def handle_call({:add, uri, new_types}, _from, state) do
    new_types =
      state
      |> Map.get(uri, [])
      |> Kernel.++(new_types)
      |> Enum.uniq()

    new_state = Map.put(state, uri, new_types)

    {:reply, :ok, new_state}
  end

  @doc """
    Clears the types of the supplied URI.
  """
  def handle_call({:clear, uri}, _from, state) do
    new_state =
      state
      |> Map.delete(uri)

    {:reply, :ok, new_state}
  end

  @doc """
    Retrieves the currently known types of the supplied URI.  Returns
    a tuple { :ok, types } if the types were available, or { :fail }
    when they were not.
  """
  def handle_call({:get, uri}, _from, state) do
    response =
      if Map.has_key?(state, uri) do
        {:ok, Map.get(state, uri)}
      else
        {:fail}
      end

    {:reply, response, state}
  end

  def handle_call({:put, uri, types}, _from, state) do
    {:reply, :ok, Map.put(state, uri, types)}
  end

  ### Client API / Helper functions
  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @doc """
    Adds the supplied types to the given Uri.
  """
  def add_types(uri, types, _authorization_groups) do
    GenServer.call(__MODULE__, {:add, uri, types})
  end

  @doc """
    Clears the types for the supplied Uri.
  """
  def clear(uri, _authorization_groups) do
    ALog.di(uri, "Clearing cache for uri")
    GenServer.call(__MODULE__, {:clear, uri})
  end

  @doc """
    Overrides the types of the supplied URI so it is set to the
    supplied values.
  """
  def put_types(uri, types, _authorization_groups) do
    GenServer.call(__MODULE__, {:put, uri, types})
  end

  @doc """
    Retrieves the types of the requested Uris, or fetches them from
    the database if they're not available yet.

    This function returns either a map containing the uri, mapped to a
    list of strings, or just a list of strings from which the Iri
    instances could be built.
  """
  def get_types(uris, authorization_groups) when is_list(uris) do
    uris
    |> Enum.map(fn iri -> {iri, Cache.Types.get_types(iri, authorization_groups)} end)
    |> Enum.into(%{})
  end

  def get_types(%Iri{iri: iri_value}, authorization_groups) do
    get_types(iri_value, authorization_groups)
  end

  def get_types(iri_value, authorization_groups) do
    # TODO: cope with race condition where a key is cleared whilst we
    # are fetching its types.

    case GenServer.call(__MODULE__, {:get, iri_value}) do
      {:ok, types} ->
        types
        |> ALog.di("Got cached type")

      {:fail} ->
        # fetch the types from the database

        # TODO: this should be based on a query that was parsed at
        # compiletime.

        # TODO: pass the right graphs to this query.  for now, it is
        # incorrectly assumed that triplestore will solve this problem
        # for us.  this may lead to a large overhead.

        discovered_types =
          "SELECT DISTINCT ?type WHERE { <MY_RESOURCE> a ?type }"
          |> Parser.parse_query_full()
          |> Manipulators.SparqlQuery.replace_iri("<MY_RESOURCE>", iri_value)
          |> Regen.result()
          |> ALog.di("query to find type for " <> iri_value)
          # TODO: receive query type from calling entity in the future
          |> SparqlClient.query(query_type: :read)
          |> SparqlClient.extract_results()
          |> ALog.di("results for " <> iri_value)
          |> Enum.map(fn result ->
            result
            |> Map.get("type")
            |> Map.get("value")
            # TODO: wrapping of iri should be handled correctly
            |> (fn value -> "<" <> value <> ">" end).()
          end)

        # store the types
        put_types(iri_value, discovered_types, authorization_groups)

        # return the result
        discovered_types
    end
  end
end
