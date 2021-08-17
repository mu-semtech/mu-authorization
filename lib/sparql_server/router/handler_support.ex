defmodule SparqlServer.Router.HandlerSupport do
  alias InterpreterTerms.SymbolMatch, as: Sym
  alias Updates.QueryAnalyzer
  alias QueryAnalyzer.Iri
  alias SparqlServer.Router.AccessGroupSupport, as: AccessGroupSupport
  alias QueryAnalyzer.Types.Quad, as: Quad
  alias Updates.QueryAnalyzer, as: QueryAnalyzer

  require Logger
  require ALog

  @doc """
  Handles the processing of a query.  Calculating the response whilst
  possibly getting some contents from the connection.  The new
  connection (to which the response may be sent) is yielded back,
  together with the response which should be set on the client.
  """
  @spec handle_query(String.t(), SparqlClient.query_types(), Plug.Conn.t()) ::
          {Plug.Conn.t(), any}
  def handle_query(query, kind, conn) do
    Logging.EnvLog.log(:log_incoming_sparql_queries, "Incoming SPARQL query: #{query}")

    Logging.EnvLog.inspect(query, :inspect_incoming_sparql_queries, label: "Incoming SPARQL query")

    handle_query_with_worker(query, kind, conn)
  end

  @spec try_get_mu_request_timeout(Plug.Conn.t()) :: integer | nil
  defp try_get_mu_request_timeout(conn) do
    case Plug.Conn.get_req_header(conn, "mu-request-timeout") do
      [value | _] ->
        try do
          String.to_integer(value)
        rescue
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Handles the query, like handle_query/3 but using a worker instead.
  This should speed up the execution.
  """
  def handle_query_with_worker(query, kind, conn) do
    # TODO: treat timeout more exactly by subtracting time needed for fetching worker
    timeout =
      try_get_mu_request_timeout(conn) ||
        Application.get_env(:"mu-authorization", :query_max_processing_time)

    :poolboy.transaction(
      :query_worker,
      fn pid ->
        try do
          GenServer.call(pid, {:handle_query, query, kind, conn}, timeout)
        catch
          :exit, {:timeout, call_info} ->
            Support.JobCancellation.cancel!(pid)
            exit({:timeout, call_info})
        end
      end,
      timeout
    )
  end

  @doc """
  Ensure the syntax is stored in the template local store.
  """
  def ensure_syntax_in_store(template_local_store) do
    if Map.has_key?(template_local_store, :sparql_syntax) do
      template_local_store
    else
      Map.put(template_local_store, :sparql_syntax, Parser.parse_sparql())
    end
  end

  defp maybe_cancel_job_for_testing do
    failure_rate = Application.get_env(:"mu-authorization", :testing_auth_query_error_rate)

    if is_float(failure_rate) and :rand.uniform() < failure_rate do
      IO.puts("Letting query fail from failure_rate")
      throw({:job_cancelled})
    end
  end

  def handle_query_with_template_local_store(query, kind, conn, template_local_store) do
    maybe_cancel_job_for_testing()

    top_level_key =
      case kind do
        :query -> :QueryUnit
        :update -> :UpdateUnit
        :any -> :Sparql
      end

    new_template_local_store = ensure_syntax_in_store(template_local_store)

    {parsed_form, new_template_local_store} =
      query
      |> ALog.di("Raw received query")
      |> String.trim()
      # TODO: check if this is valid and/or ensure parser skips \r between words.
      |> String.replace("\r", "")
      |> Parser.parse_query_full_local(top_level_key, new_template_local_store)

    parsed_form =
      parsed_form
      |> wrap_query_in_toplevel
      |> ALog.di("Wrapped parsed query")

    if is_select_query(parsed_form) do
      # TODO: Check where the default_graph is used where these options are passed and verify whether this is a sensible name.
      options = %{
        default_graph: Iri.from_iri_string("<http://mu.semte.ch/application>", %{}),
        prefixes: %{
          "xsd" => Iri.from_iri_string("<http://www.w3.org/2001/XMLSchema#>"),
          "foaf" => Iri.from_iri_string("<http://xmlns.com/foaf/0.1/>")
        }
      }

      Cache.Deltas.flush(options)

      {conn, new_parsed_forms} = manipulate_select_query(parsed_form, conn)

      query_type =
        if Enum.any?(new_parsed_forms, fn q -> !is_select_query(q) end) do
          :read
        else
          :write
        end

      encoded_response =
        new_parsed_forms
        |> ALog.di("New parsed forms")
        |> Enum.map(&SparqlClient.execute_parsed(&1, request: conn, query_type: query_type))
        |> List.first()
        |> Poison.encode!()

      {conn, {200, encoded_response}, new_template_local_store}
    else
      {conn, authorization_groups} = AccessGroupSupport.calculate_access_groups(conn)

      origin =
        conn
        |> Map.get(:remote_ip)
        |> Tuple.to_list()
        |> Enum.join(".")


      mu_call_id_trail =
        (case Plug.Conn.get_req_header(conn, "mu-call-id-trail") do
          # ignore extra values for now, they should not happen, but
          # if they do we don't want to crash either
          [value | _] -> Poison.decode!(value)
            _ -> []
        end)
        |> Kernel.++(Plug.Conn.get_req_header(conn, "mu-call-id"))
        |> Poison.encode!()

      analyzed_quads =
        parsed_form
        |> ALog.di("Parsed query")
        |> QueryAnalyzer.quad_changes(%{
          default_graph: Iri.from_iri_string("<http://mu.semte.ch/application>", %{}),
          authorization_groups: authorization_groups
        })
        |> Enum.reject(&match?({_, []}, &1))
        |> ALog.di("Non-empty operations")
        |> enrich_manipulations_with_access_rights(authorization_groups)
        |> maybe_verify_all_triples_written()

      case analyzed_quads do
        {:fail, reason} ->
          encoded_response_string = Poison.encode!(%{errors: [%{status: "403", title: reason}]})
          {conn, {403, encoded_response_string}, new_template_local_store}

        _ ->
          analyzed_quads
          |> Enum.map(fn {manipulation, _requested_quads, effective_quads} ->
            {manipulation, effective_quads}
          end)
          |> Cache.Deltas.add_deltas(
            :construct,
            origin: origin,
            mu_call_id_trail: mu_call_id_trail,
            authorization_groups: AccessGroupSupport.encode_json_access_groups(authorization_groups)
          )

          succesful = Poison.encode!(%{sucessful: true})
          {conn, {200, succesful}, new_template_local_store}
      end
    end
  end

  def wrap_query_in_toplevel(%Sym{symbol: :Sparql} = matched) do
    matched
  end

  def wrap_query_in_toplevel(%Sym{string: str} = matched) do
    # Only public for benchmark
    %Sym{
      symbol: :Sparql,
      string: str,
      submatches: [matched]
    }
  end

  @doc """
  Yields non-nil iff the query is a select query.
  """
  def is_select_query(query) do
    case query do
      %Sym{
        symbol: :Sparql,
        submatches: [%Sym{symbol: :QueryUnit}]
      } ->
        true

      _ ->
        false
    end
  end

  ### Manipulates the select query yielding back the valid set of
  ### queries which should be executed on the database.
  defp manipulate_select_query(query, %Plug.Conn{} = conn) do
    {conn, authorization_groups} = AccessGroupSupport.calculate_access_groups(conn)

    {conn, query} =
      if authorization_groups == :sudo do
        {conn, query}
      else
        query = manipulate_select_query(query, authorization_groups, :read)
        conn = AccessGroupSupport.put_access_groups(conn, authorization_groups)

        {conn, query}
      end

    {conn, [query]}
  end

  @doc """
  Updates a select query to cope with the supplied access rights
  """
  @spec manipulate_select_query(
          Parser.query(),
          SparqlServer.Router.AccessGroupSupport.decoded_json_access_groups(),
          SparqlClient.query_types()
        ) :: Parser.query()
  def manipulate_select_query(query, authorization_groups, useage) do
    if authorization_groups == :sudo do
      query
    else
      query
      |> Manipulators.SparqlQuery.remove_from_statements()
      |> Acl.process_query(Acl.UserGroups.for_use(useage), authorization_groups)
      |> elem(0)
    end
  end


  defp enrich_manipulations_with_access_rights(manipulations, authorization_groups) do
    manipulations
    |> Enum.map(fn {kind, quads} ->
      processed_quads = enforce_write_rights(quads, authorization_groups)
      {kind, quads, processed_quads}
    end)
  end

  # If requested by configuration, this code will verify all triples
  # are going to be written to the triplestore.
  defp maybe_verify_all_triples_written(enriched_manipulations) do
    if Application.get_env(:"mu-authorization", :error_on_unwritten_data) do
      all_manipulations_complete =
        enriched_manipulations
        |> Enum.all?(fn {_manipulation, requested_quads, effective_quads} ->
          requested_triples =
            requested_quads
            |> Enum.map(&{&1.subject, &1.predicate, &1.object})
            |> MapSet.new()

          effective_triples =
            effective_quads
            |> Enum.map(&{&1.subject, &1.predicate, &1.object})
            |> MapSet.new()

          all_triples_written? = MapSet.equal?(requested_triples, effective_triples)

          unless all_triples_written? do
            Logging.EnvLog.inspect(
              MapSet.difference(requested_triples, effective_triples),
              :error,
              label: "These triples would not be written to the triplestore"
            )
          end

          all_triples_written?
        end)

      if all_manipulations_complete do
        enriched_manipulations
      else
        {:fail, "Not all triples would be written to the triplestore."}
      end
    else
      enriched_manipulations
    end
  end


  @spec enforce_write_rights([Quad.t()], Acl.UserGroups.Config.t()) :: [Quad.t()]
  defp enforce_write_rights(quads, authorization_groups) do
    Logger.info("Enforcing write rights")
    user_groups_for_update = Acl.UserGroups.for_use(:write)

    processed_quads =
      quads
      |> Acl.process_quads_for_update(user_groups_for_update, authorization_groups)
      |> elem(1)
      |> ALog.di("processed quads")

    processed_quads
  end
end
