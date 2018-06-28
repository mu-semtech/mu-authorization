defmodule Interpreter.Diff.Store do
  @doc """
  Parses the string query based on the current templates for the
  supplied symbol.  Yields {:fail} on failure, or the parsed query
  solution on success.

  This encompasses all logic.  The resulting solution will
  automatically be pushed onto the current solution.  The response
  will not calculate (nor push) a solution into the store if no
  solution could be found.  It is advised to push the solution using
  &Interpreter.Diff.Store.push_solution/1 when a solution has been
  calculated.
  """
  def parse( query_string, symbol\\:Sparql ) do
    templates( symbol )
    |> Enum.reduce_while( {:fail}, fn (template, _) ->
      case Interpreter.Diff.Template.fill( template, query_string ) do
        {:fail} ->
          {:cont, {:fail}}
        solution ->
          Interpreter.Diff.Store.Manipulator.maybe_push_solution( template, solution )
          {:halt, solution}
      end
    end )
  end

  @doc """
  Pushes a query solution which was not based on a template into the
  store.
  """
  def push_solution( solution ) do
    Interpreter.Diff.Store.Manipulator.push_solution( solution )
    solution
  end

  @doc """
  Pushes a query solution which was not based on a template into the
  store.
  """
  def maybe_push_solution( solution ) do
    if :rand.uniform(10) == 1 do
      Interpreter.Diff.Store.Manipulator.push_solution( solution )
    end
    solution
  end

  @doc """
  Yields all templates currently in the store, sorted by score.
  """
  def templates( symbol\\:Sparql ) do
    # Templates are always returned sorted by score, no need to sort
    # them again.
    Interpreter.Diff.Store.Storage.templates()
  end
end

defmodule Interpreter.Diff.Store.Storage do
  use GenServer

  @doc """
  We store our state in a tuple.  The first element of the tuple is an
  array containing templates which can be used to solve queries.  The
  second element of our solution contains an array of unused
  query_solutions.  These may be used to construct templates at a
  later stage.
  """
  def init(_) do
    {:ok, %{}}
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def handle_cast( {:push_solution, query_solution, symbol}, map ) do
    {templates, solutions} = Map.get( map, symbol, {[],[]} )
    new_state = Map.put( map, symbol, { templates, [query_solution|solutions] } )
    {:noreply, new_state}
  end

  def handle_cast( {:set_solutions, solutions, symbol}, map ) do
    {templates, _} = Map.get( map, symbol, {[],[]} )
    new_state = Map.put( map, symbol, { templates, solutions } )
    {:noreply, new_state}
  end

  def handle_cast( {:push_template, template, symbol}, map ) do
    {templates, solutions} = Map.get( map, symbol, {[],[]} )

    new_templates =
      [ template | templates ]
      |> Interpreter.Diff.Template.fold_duplicates
      |> Interpreter.Diff.Template.sort

    new_state = Map.put( map, symbol, { new_templates, solutions } )
    {:noreply, new_state}
  end

  def handle_cast( {:set_templates, templates, symbol}, map ) do
    {_, solutions} = Map.get( map, symbol, {[],[]} )
    new_state = Map.put( map, symbol, { templates, solutions } )
    {:noreply, new_state}
  end

  def handle_call( {:templates, symbol}, _, map ) do
    {templates,_} = Map.get(map, symbol, {[],[]})
    {:reply, templates, map}
  end

  def handle_call( {:solutions, symbol}, _, map ) do
    {_,solutions} = Map.get(map, symbol, {[],[]})
    {:reply, solutions, map}
  end

  def templates( symbol\\:Sparql ) do
    GenServer.call( __MODULE__, { :templates, symbol } )
  end

  def solutions( symbol\\:Sparql ) do
    GenServer.call( __MODULE__, { :solutions, symbol } )
  end
end

defmodule Interpreter.Diff.Store.Manipulator do
  use GenServer

  # TODO: Ensure the store does not contain an infinite amount of
  # solutions to try.

  @moduledoc """
  Manipulation of the store takes time.  Queries need to be merged and
  other calculations need to be made.  This could happen in the thread
  of the consuming entity, but they don't really care about this.  The
  Manipulator offloads this.
  """
  def init(_) do
    {:ok, nil}
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def handle_cast( {:push_solution, solution}, _ ) do
    symbol = main_symbol( solution )

    # Try to construct a template between this solution and any other solutions
    new_templates =
      Interpreter.Diff.Store.Storage.solutions(symbol)
      |> Enum.map( &Interpreter.Diff.Template.make_template( solution, &1 ) )
      |> Enum.reject( &match?({:fail},&1) )
      |> Interpreter.Diff.Template.fold_duplicates # in case we mtach with multiple other queries
      |> Interpreter.Diff.Template.sort

    case new_templates do
      [] ->
        GenServer.cast( Interpreter.Diff.Store.Storage, {:push_solution, solution, symbol} )
        {:noreply, nil}
      [new_template|_] ->
        # Remove the matches for our new template from the 
        new_template_solutions = Interpreter.Diff.Template.used_solutions( new_template )
        new_solutions =
          Interpreter.Diff.Store.Storage.solutions( symbol )
          |> Enum.reject( fn (x) -> Enum.member? new_template_solutions, x end )

        GenServer.cast( Interpreter.Diff.Store.Storage, {:set_solutions, new_solutions, symbol} )

        # Try to push the highest scoring template into the store
        new_stored_templates =
          [new_template | Interpreter.Diff.Store.Storage.templates(symbol)]
          |> Interpreter.Diff.Template.fold_duplicates # folding in case we fetched new matches
          |> Interpreter.Diff.Template.sort

        GenServer.cast( Interpreter.Diff.Store.Storage, {:set_templates, new_stored_templates, symbol} )
        {:noreply, nil}
    end
  end

  def handle_cast( {:push_solution, template, solution }, _ ) do
    # We know there is a race condition going on here, but it is for
    # the cache.  If this cache has stale data, it will be filled
    # later on with minimal extra work having been done.
    symbol = main_symbol( solution )

    new_templates =
      Interpreter.Diff.Template.exhaustive_better_templates( template, solution )
      |> Kernel.++( Interpreter.Diff.Store.Storage.templates )
      |> Interpreter.Diff.Template.fold_duplicates
      |> Interpreter.Diff.Template.sort

    GenServer.cast( Interpreter.Diff.Store.Storage, {:set_templates, new_templates, symbol } )
    {:noreply, nil}
  end

  defp main_symbol( %InterpreterTerms.SymbolMatch{symbol: symbol} ), do: symbol

  @doc """
  Pushes a parsed query, solved by the given solution, into the store.
  Splitting or merging the solutions as required.

  The symbol under which to store the solution is derived from the
  solution's top level element.
  """
  def push_solution( template, solution ) do
    GenServer.cast( __MODULE__, {:push_solution, template, solution } )
  end
  def maybe_push_solution( template, solution ) do
    if :rand.uniform( 10 ) == 1 do
      GenServer.cast( __MODULE__, {:push_solution, template, solution } )
    end
  end

  @doc """
  Pushes the solution into the store, without a template being
  attached to it (eg: there was no template that satisfied this query
  solution, but we want to build templates on top of it in the future.

  The symbol under which to store the solution is derived from the
  solution's top level element.
  """
  def push_solution( solution ) do
    GenServer.cast( __MODULE__, {:push_solution, solution} )
    solution
  end
  def maybe_push_solution( solution ) do
    if :rand.uniform( 10 ) == 1 do
      GenServer.cast( __MODULE__, {:push_solution, solution} )
    end
    solution
  end

end
