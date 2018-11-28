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
    arrays = Interpreter.Diff.Store.Storage.arrays( symbol )
    # IO.puts "templates: #{Enum.count(arrays)}"

    arrays
    |> Enum.reduce_while( {:fail}, fn (array, _) ->
      case Interpreter.Diff.Template.fill_array( array, query_string ) do
        {:fail} ->
          # IO.puts "no"
          {:cont, {:fail}}
        filled_array ->
          # IO.puts "yes"
          # IO.inspect array, label: "Array that was filled"
          { tree, score } = Interpreter.Diff.Store.Storage.template_tree_and_score_for_array( array, symbol )
          # template = Interpreter.Diff.Store.Storage.template_for_array( array, symbol )
          if tree do
            # score = Interpreter.Diff.Template.score( template )
            # IO.inspect( score , label: "Template score" )
            # IO.inspect( template, label: "Template" )
            # tree = Interpreter.Diff.Template.tree( template )
            {solution,[]} = Interpreter.Diff.Template.fill_tree( filled_array, tree )
            # IO.inspect( solution, label: "Solution" )
            if score > 0.9 do
              Interpreter.Diff.Store.Manipulator.maybe_push_template_solution_for_array( array, solution, symbol, 0.02 )
            else
              Interpreter.Diff.Store.Manipulator.maybe_push_template_solution_for_array( array, solution, symbol, 0.2 )
            end
            {:halt, solution}
          else
            # IO.puts "Template cleared, trying other templates"
            {:cont, {:fail}}
          end
      end
    end )
  end

  def parse_with_local_store( query_string, rule_name, local_template_store ) do
    arrays = Interpreter.Diff.Store.Storage.arrays( rule_name, local_template_store )
    # IO.puts "templates: #{Enum.count(arrays)} in #{inspect self()}"
    # IO.inspect arrays, label: "Arrays in #{inspect self()}"

    arrays
    |> Enum.reduce_while( {:fail}, fn (array, _) ->
      case Interpreter.Diff.Template.fill_array( array, query_string ) do
        {:fail} ->
          {:cont, {:fail}}
        filled_array ->
          { tree, score } = Interpreter.Diff.Store.Storage.template_tree_and_score_for_array_sync( array, rule_name, local_template_store )
          if tree do
            # IO.puts "Build solution from tree"
            {solution,[]} = Interpreter.Diff.Template.fill_tree( filled_array, tree )
            new_store =
              if score > 0.9 do
                Interpreter.Diff.Store.Manipulator.maybe_push_template_solution_for_array_sync( array, solution, rule_name, 0.02, local_template_store )
              else
                Interpreter.Diff.Store.Manipulator.maybe_push_template_solution_for_array_sync( array, solution, rule_name, 0.2, local_template_store )
              end
            {:halt, {solution, new_store}}
          else
            {:cont, {:fail}}
          end
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
  def maybe_push_solution( solution, chance\\0.1 ) do
    if :rand.uniform < chance do
      Interpreter.Diff.Store.Manipulator.push_solution( solution )
    end
    solution
  end

  @doc """
  Pushes a query solution which was not based on a template into the
  store.
  """
  def maybe_push_solution_sync( solution, chance, rule_name, template_local_store ) do
    if :rand.uniform <= chance do
      Interpreter.Diff.Store.Manipulator.push_single_solution_sync( solution, rule_name, template_local_store )
    else
      template_local_store
    end
  end

  @doc """
  Yields all templates currently in the store, sorted by score.
  """
  def templates( symbol\\:Sparql ) do
    # Templates are always returned sorted by score, no need to sort
    # them again.
    Interpreter.Diff.Store.Storage.templates(symbol)
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

  def handle_call( { :arrays, symbol }, _, map ) do
    {templates,_} = Map.get(map, symbol, {[],[]})
    {:reply, Enum.map( templates, &Interpreter.Diff.Template.array/1 ), map}
  end

  def handle_call( { :template_for_array, array, symbol }, _, map ) do
    {templates,_} = Map.get(map, symbol, {[],[]})
    {:reply,
     Enum.find( templates, fn (template) -> Interpreter.Diff.Template.array(template) == array end ),
     map}
  end

  def handle_call( { :template_tree_and_score_for_array, array, symbol }, _, map ) do
    {templates,_} = Map.get(map, symbol, {[],[]})
    template = Enum.find( templates, fn (template) -> Interpreter.Diff.Template.array(template) == array end )

    if template do
      { :reply,
        {Interpreter.Diff.Template.tree( template ), Interpreter.Diff.Template.score( template )},
        map }
    else
    {:reply, {nil,nil}, map}

    end
  end

  def templates( symbol\\:Sparql ) do
    GenServer.call( __MODULE__, { :templates, symbol } )
  end

  def templates_sync( rule_name, %{ template_store: template_store } ) do
    {templates,_} = Map.get( template_store, rule_name, {[],[]} )
    templates
  end

  def solutions( symbol\\:Sparql ) do
    GenServer.call( __MODULE__, { :solutions, symbol } )
  end

  def solutions_sync( rule_name, %{ template_store: template_store } ) do
    {_,solutions} = Map.get(template_store, rule_name, {[],[]})
    solutions
  end

  def push_solution_sync( query_solution, rule_name, %{ template_store: _template_store } = local_template_store ) do
    Map.update! local_template_store, :template_store, fn (template_store) ->
      template_store
      # Ensure value exists
      |> Map.update( rule_name, {[],[]}, fn (x) -> x end )
      # Update value
      |> Map.update!( rule_name, fn ({templates, solutions}) ->
        { templates, [query_solution|solutions] }
      end )
    end
  end

  def set_solutions( solutions, rule_name, %{ template_store: _template_store } = local_template_store ) do
    Map.update! local_template_store, :template_store, fn (template_store) ->
      template_store
      # Ensure value exists
      |> Map.update( rule_name, {[],[]}, fn (x) -> x end )
      # Update value
      |> Map.update!( rule_name, fn ({templates, _solutions}) ->
        { templates, solutions }
      end )
    end
  end

  def set_templates_sync( templates, rule_name, %{ template_store: _template_store } = local_template_store ) do
    Map.update! local_template_store, :template_store, fn (template_store) ->
      template_store
      # Ensure value exists
      |> Map.update( rule_name, {[],[]}, fn (x) -> x end )
      # Update value
      |> Map.update!( rule_name, fn ({_templates, solutions}) ->
        { templates, solutions }
      end )
    end
  end

  def arrays( symbol\\:Sparql ) do
    GenServer.call( __MODULE__, { :arrays, symbol } )
  end

  def arrays( rule_name, %{ template_store: template_store } ) do
    {templates,_} = Map.get(template_store, rule_name, {[],[]})
    Enum.map( templates, &Interpreter.Diff.Template.array/1 )
  end

  def template_for_array( array, symbol\\:Sparql ) do
    GenServer.call( __MODULE__, { :template_for_array, array, symbol } )
  end

  def template_for_array_sync( array, rule_name, %{ template_store: template_store } ) do
    {templates,_} = Map.get(template_store, rule_name, {[],[]})
    Enum.find( templates, fn (template) -> Interpreter.Diff.Template.array(template) == array end )
  end

  def template_tree_and_score_for_array( array, symbol\\:Sparql ) do
    GenServer.call( __MODULE__, { :template_tree_and_score_for_array, array, symbol } )
  end

  def template_tree_and_score_for_array_sync( array, rule_name, %{ template_store: template_store } ) do
    {templates,_} = Map.get(template_store, rule_name, {[],[]})
    template = Enum.find( templates, fn (template) -> Interpreter.Diff.Template.array(template) == array end )

    if template do
      {Interpreter.Diff.Template.tree( template ), Interpreter.Diff.Template.score( template )}
    else
      {nil,nil}
    end
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
      |> Interpreter.Diff.Template.fold_duplicates( limit: 5 ) # in case we match with multiple other queries
      |> Interpreter.Diff.Template.sort

    case new_templates do
      [] ->
        GenServer.cast( Interpreter.Diff.Store.Storage, {:push_solution, solution, symbol} )
        {:noreply, nil}
      [new_template|_] ->
        # Remove the matches for our new template from the 
        new_template_solutions = Interpreter.Diff.Template.used_solutions( new_template )
        all_solutions =
          Interpreter.Diff.Store.Storage.solutions( symbol )
          |> Enum.reject( fn (x) -> Enum.member? new_template_solutions, x end )

        new_solutions = if Enum.count( all_solutions ) > 4 do
          Enum.take_random( all_solutions, 4 )
        else
          all_solutions
        end

        GenServer.cast( Interpreter.Diff.Store.Storage, {:set_solutions, new_solutions, symbol} )

        # Try to push the highest scoring template into the store
        new_stored_templates =
          [new_template | Interpreter.Diff.Store.Storage.templates(symbol)]
          |> Interpreter.Diff.Template.fold_duplicates( limit: 4 ) # folding in case we fetched new matches
          |> Enum.take_random( 7 )
          |> Enum.map( &Interpreter.Diff.Template.cache_score/1 )
          |> Interpreter.Diff.Template.sort

        # IO.puts "Storing #{Enum.count(new_stored_templates)} templates"

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
      |> Interpreter.Diff.Template.fold_duplicates( limit: 5 ) # folding in case we fetched new matches
      |> Enum.take_random( 7 )
      |> Enum.map( &Interpreter.Diff.Template.cache_score/1 )
      |> Interpreter.Diff.Template.sort

    GenServer.cast( Interpreter.Diff.Store.Storage, {:set_templates, new_templates, symbol } )
    {:noreply, nil}
  end

  def handle_cast( {:push_solution_for_array, array, solution, symbol }, arg ) do
    template = Interpreter.Diff.Store.Storage.template_for_array( array, symbol )
    if template do
      handle_cast( {:push_solution, template, solution}, arg )
    end
  end

  def push_solution_for_array_sync( array, solution, rule_name, local_template_store ) do
    template = Interpreter.Diff.Store.Storage.template_for_array_sync( array, rule_name, local_template_store )
    if template do
      push_solution_sync( template, rule_name, solution, local_template_store )
    else
      local_template_store
    end
  end

  def push_solution_sync( template, rule_name, solution, local_template_store ) do
    new_templates =
      # Get the new templates
      Interpreter.Diff.Template.exhaustive_better_templates( template, solution )
      # Add them to the existing tepmplates
      |> Kernel.++( Interpreter.Diff.Store.Storage.templates_sync( rule_name, local_template_store ) )
      |> Interpreter.Diff.Template.fold_duplicates( limit: 20 ) # folding in case we fetched new matches
      |> Enum.map( &Interpreter.Diff.Template.cache_score/1 )
      |> Interpreter.Diff.Template.sort

    Enum.map( new_templates, fn (%Interpreter.Diff.Template{ array_template: var_arr }) ->
      Enum.count var_arr
    end )

    # Set the solution
    Interpreter.Diff.Store.Storage.set_templates_sync( new_templates, rule_name, local_template_store )
  end

  def push_single_solution_sync( solution, rule_name, local_template_store ) do
    # Try to construct a template between this solution and any other solutions
    current_solutions =
      Interpreter.Diff.Store.Storage.solutions_sync(rule_name, local_template_store)

    new_local_template_store =
      Interpreter.Diff.Store.Storage.push_solution_sync( solution, rule_name, local_template_store )

    current_solutions =
      Interpreter.Diff.Store.Storage.solutions_sync(rule_name, new_local_template_store)

    new_templates =
      current_solutions
      |> Enum.map( &Interpreter.Diff.Template.make_template( solution, &1 ) )
      |> Enum.reject( &match?({:fail},&1) )
      |> Enum.reject( fn (%Interpreter.Diff.Template{ array_template: var_arr }) -> Enum.count( var_arr ) == 1 end )
      |> Interpreter.Diff.Template.fold_duplicates( limit: 10 ) # in case we match with multiple other queries
      |> Interpreter.Diff.Template.sort

    case new_templates do
      [] ->
        Interpreter.Diff.Store.Storage.push_solution_sync( solution, rule_name, local_template_store )
      [new_template|_] ->
        # Remove the matches for our new template from the
        new_template_solutions =
          Interpreter.Diff.Template.used_solutions( new_template )
        all_solutions =
          Interpreter.Diff.Store.Storage.solutions( rule_name )
          |> Enum.reject( fn (x) -> Enum.member? new_template_solutions, x end )

        new_solutions = if Enum.count( all_solutions ) > 4 do
          Enum.take_random( all_solutions, 4 )
        else
          all_solutions
        end

        new_local_template_store =
          Interpreter.Diff.Store.Storage.set_solutions( new_solutions, rule_name, local_template_store )

        # Try to push the highest scoring template into the store
        new_stored_templates =
          [new_template | Interpreter.Diff.Store.Storage.templates_sync(rule_name, new_local_template_store)]
          |> Interpreter.Diff.Template.fold_duplicates( limit: 4 ) # folding in case we fetched new matches
          |> Enum.take_random( 7 )
          |> Enum.map( &Interpreter.Diff.Template.cache_score/1 )
          |> Interpreter.Diff.Template.sort

        # IO.puts "Storing #{Enum.count(new_stored_templates)} templates at #{inspect self()}"
        Interpreter.Diff.Store.Storage.set_templates_sync( new_stored_templates, rule_name, new_local_template_store )
    end
  end


  def main_symbol( %InterpreterTerms.SymbolMatch{symbol: symbol} ), do: symbol

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
  def maybe_push_solution( solution, chance\\0.1 ) when is_number( chance )do
    if :rand.uniform < chance do
      GenServer.cast( __MODULE__, {:push_solution, solution} )
    end
    solution
  end

  @doc """
  Pushes a parsed query, solved by the given solution, into the store.
  Splitting or merging the solutions as required.

  The symbol under which to store the solution is derived from the
  solution's top level element.
  """
  def push_solution( template, solution ) do
    GenServer.cast( __MODULE__, {:push_solution, template, solution } )
  end
  def maybe_push_template_solution( template, solution, chance\\0.1 ) do
    if :rand.uniform < chance do
      GenServer.cast( __MODULE__, {:push_solution, template, solution } )
    end
  end

  def maybe_push_template_solution_for_array( array, solution, symbol, chance\\0.1 ) do
    if :rand.uniform < chance do
      GenServer.cast( __MODULE__, {:push_solution_for_array, array, solution, symbol } )
    end
  end

  def maybe_push_template_solution_for_array_sync( array, solution, rule_name, chance, %{ template_store: _template_store } = local_template_store ) do
    if :rand.uniform < chance do
      push_solution_for_array_sync( array, solution, rule_name, local_template_store )
    else
      local_template_store
    end
  end

end
