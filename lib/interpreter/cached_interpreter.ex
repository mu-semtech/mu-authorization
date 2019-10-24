# We want to check if the first portion of the query consists of a set
# of prefixes which we already know.  If that is the case, we can
# shortcut the definition and pull these prefixes off.
#
# However, it may be that there are other prefixes after the ones
# we've seen.  Hence we need to cope with that situation as well.
#
# Once we have our prefixes, we should move them to the right spot.

defmodule Interpreter.CachedInterpreter do
  alias InterpreterTerms.SymbolMatch, as: Sym

  require Logger
  require ALog
  use GenServer

  def init(_) do
    {:ok, %{}}
  end

  def handle_call(:list, _from, elements) do
    # TODO: We should calculate the keys in the consuming code, or
    # maintain a corresponding list
    {:reply, Map.keys(elements), elements}
  end

  def handle_call({:get, prologue_string}, _from, elements) do
    {:reply, Map.get(elements, prologue_string), elements}
  end

  def handle_cast({:add, prologue_string, prologue_element}, elements) do
    # TODO: We should set a maximum and see how many times the
    # solution was used.  There may be cases with dynamic prefixes
    # which would cause something similar to a memory leak.
    {:noreply, Map.put(elements, prologue_string, prologue_element)}
  end

  # Tries to find a full solution for the query parsing.
  def parse_query_full(query, :Sparql, syntax) do
    query_unit_solution = parse_query_full(query, :QueryUnit, syntax)

    sub_solution =
      %Sym{string: substring} =
      query_unit_solution || parse_query_full(query, :UpdateUnit, syntax)

    %Sym{symbol: :Sparql, string: substring, submatches: [sub_solution]}
  end

  def parse_query_full(query, symbol, syntax) when symbol in [:QueryUnit, :UpdateUnit] do
    {sub_unit, no_prologue_unit} =
      if symbol == :QueryUnit do
        {:Query, :QueryAfterPrologue}
      else
        {:Update, :UpdateAfterPrologue}
      end

    prologue_str = find_longest_usable_prologue(query)

    if prologue_str do
      cut_query = cut_prologue_string(query, prologue_str)
      cached_prologue = get_cached_prologue(prologue_str)

      after_prologue_solution = parse_query_full_no_cache(cut_query, no_prologue_unit, syntax)

      if after_prologue_solution do
        %Sym{submatches: discovered_matches, whitespace: whitespace} = after_prologue_solution

        [
          %Sym{
            whitespace: first_discovered_submatch_whitespace,
            string: first_discovered_submatch_string
          } = first_discovered_submatch
          | rest_discovered_submatches
        ] = discovered_matches

        first_discovered_submatch_with_whitespace = %{
          first_discovered_submatch
          | whitespace: whitespace <> first_discovered_submatch_whitespace,
            string: whitespace <> first_discovered_submatch_string
        }

        %Sym{
          symbol: symbol,
          string: query,
          submatches: [
            %Sym{
              symbol: sub_unit,
              string: query,
              submatches: [
                cached_prologue,
                first_discovered_submatch_with_whitespace
                | rest_discovered_submatches
              ]
            }
          ]
        }
      else
        parse_query_full_no_cache(query, symbol, syntax)
      end
    else
      parse_query_full_no_cache(query, symbol, syntax)
    end
  end

  def parse_query_full(query, symbol, syntax) do
    rule = {:symbol, symbol}
    state = %Generator.State{chars: String.graphemes(query), syntax: syntax}

    base_solution =
      EbnfParser.GeneratorConstructor.dispatch_generation(rule, state)
      |> find_full_solution_for_generator

    if base_solution do
      solution =
        base_solution
        |> Map.get(:match_construct)
        |> List.first()

      cache_prologue(solution)
      solution
    end
  end

  def parse_query_full_no_cache(query, symbol, syntax) do
    rule = {:symbol, symbol}
    state = %Generator.State{chars: String.graphemes(query), syntax: syntax}

    base_solution =
      EbnfParser.GeneratorConstructor.dispatch_generation(rule, state)
      |> find_full_solution_for_generator

    if base_solution do
      solution =
        base_solution
        |> Map.get(:match_construct)
        |> List.first()

      cache_prologue(solution)
      solution
    end
  end

  defp find_longest_usable_prologue(query) do
    list_cached_prologues()
    |> Enum.sort_by(&byte_size/1, &>=/2)
    |> Enum.find(fn prologue_string ->
      prologue_size = byte_size(prologue_string)

      if prologue_size <= byte_size(query) do
        <<query_prefix::binary-size(prologue_size), _::binary>> = query
        query_prefix == prologue_string
      end
    end)
  end

  def cut_prologue_string(query, prologue_string) do
    # Note: this code assumes the prefix string is the first part of query
    prologue_size = byte_size(prologue_string)
    <<_::binary-size(prologue_size), rest_query::binary>> = query

    rest_query
  end

  defp find_full_solution_for_generator(generator) do
    case EbnfParser.Generator.emit(generator) do
      {:ok, new_state, answer} ->
        if Generator.Result.full_match?(answer) do
          answer
        else
          find_full_solution_for_generator(new_state)
        end

      {:fail} ->
        nil
    end
  end

  defp cache_prologue(%Sym{symbol: :Prologue, string: str} = prologue) do
    # Cache this prologue
    GenServer.cast(__MODULE__, {:add, str, prologue})
  end

  defp cache_prologue(%Sym{submatches: [submatch | _]}) do
    # Keep walking the left branch to find the Prologue
    cache_prologue(submatch)
  end

  defp cache_prologue(_) do
    # This case may appear with the new caches
  end

  def list_cached_prologues() do
    GenServer.call(__MODULE__, :list)
  end

  def get_cached_prologue(string) do
    GenServer.call(__MODULE__, {:get, string})
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
end
