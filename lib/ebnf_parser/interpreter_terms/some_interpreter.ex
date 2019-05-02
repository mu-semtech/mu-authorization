alias InterpreterTerms.Some.Interpreter, as: SomeEmitter
alias Generator.State, as: State
alias Generator.Result, as: Result

defmodule SomeEmitter do
  defstruct [
    :element,
    :state,
    {:selfgenerator, :none},
    {:base_result, :none},
    {:restgenerator, :none},
    {:locked_states, []}
  ]

  defimpl EbnfParser.Generator do
    def emit(%SomeEmitter{} = emitter) do
      SomeEmitter.walk(emitter)
    end
  end

  def walk(%SomeEmitter{} = some) do
    case some
         |> ensure_base_result
         |> ensure_selfgenerator_exists
         |> ensure_restgenerator_exists do
      {:ok, some} ->
        some
        |> emit_restgenerator_result

      {:ok, generator, result} ->
        {:ok, generator, result}

      # dialyzer is sure this cannot occur.  Leaving it for future
      # implementations
      # _ ->
      #   yield_none_result(some)
    end
  end

  defp ensure_base_result(%SomeEmitter{state: %State{chars: chars}, base_result: :none} = some) do
    base_result = %Result{leftover: chars}
    %{some | base_result: base_result}
  end

  # TODO: merge the following two states?  both yield some, regardless
  # of the further state
  defp ensure_base_result(%SomeEmitter{state: %State{chars: _chars}} = some) do
    some
  end

  defp ensure_base_result(%SomeEmitter{} = some) do
    some
  end

  # defp yield_none_result(%SomeEmitter{state: %State{chars: chars}}) do
  #   {:ok, %InterpreterTerms.Nothing{}, %Result{leftover: chars}}
  # end

  def ensure_selfgenerator_exists(
        %SomeEmitter{selfgenerator: :none, element: element, state: state} = some
      ) do
    %{some | selfgenerator: dispatch_generation(element, state)}
  end

  def ensure_selfgenerator_exists(%SomeEmitter{} = some) do
    some
  end

  defp ensure_restgenerator_exists(
         %SomeEmitter{
           selfgenerator: selfgen,
           restgenerator: :none,
           state: state,
           base_result: base_result,
           locked_states: locked_states
         } = some
       ) do
    case EbnfParser.Generator.emit(selfgen) do
      {:ok, new_selfgen, child_result} ->
        if locked_state?(some, combined_result(some, child_result)) do
          # if we are now in a locked state, skip it
          walk(%{some | selfgenerator: new_selfgen})
        else
          # generate a new result with our state as the new base state
          combined_child_result = combined_result(some, child_result)
          %{leftover: leftover} = child_result

          {:ok,
           %{
             some
             | restgenerator: %{
                 some
                 | state: %{state | chars: leftover},
                   selfgenerator: :none,
                   restgenerator: :none,
                   base_result: combined_child_result,
                   locked_states: [combined_child_result | locked_states]
               },
               selfgenerator: new_selfgen
           }}
        end

      _ ->
        # TODO: I think this code-path is broken.  We cannot simply
        # emit a result from here unless accepted by our calling
        # function.

        # Emit our own state as a result
        # if locked_state?( some, base_result ) do
        #   { :fail }
        # else
        {:ok, %InterpreterTerms.Nothing{}, base_result}
        # end
    end
  end

  defp ensure_restgenerator_exists(%SomeEmitter{} = some) do
    {:ok, some}
  end

  defp emit_restgenerator_result(%SomeEmitter{restgenerator: restgen} = some) do
    case EbnfParser.Generator.emit(restgen) do
      {:ok, new_restgen, result} ->
        {:ok, %{some | restgenerator: new_restgen}, result}

      _ ->
        # Emit a new result from our selfgenerator and continue walking
        walk(%{some | restgenerator: :none})
    end
  end

  defp locked_state?(%SomeEmitter{locked_states: states}, result) do
    Enum.member?(states, result)
  end

  defp dispatch_generation(alpha, beta) do
    EbnfParser.GeneratorConstructor.dispatch_generation(alpha, beta)
  end

  defp combined_result(%SomeEmitter{base_result: base_result}, child_result) do
    Result.combine_results(base_result, child_result)
  end
end

#   # initialize the child generator
#   def walk( %SomeEmitter{ child_generator: :none, 
#                           element: element,
#                           state: state,
#                           direction: :down } = emitter ) do
#     # IO.puts "initialize the child generator"
#     # IO.inspect element
#     emitter
#     |> Map.put( :child_generator, dispatch_generation( element, state ) )
#     # |> IO.inspect
#     |> walk
#   end

#   # initialize the child generator's first result
#   def walk( %SomeEmitter{ child_generator: g,
#                           child_result: :none,
#                           locked_states: locked_states,
#                           locked_solution_results: locked_solution_results,
#                           direction: :down } = emitter ) do
#     # IO.puts "initialize the child generator's first result"
#     case emit( g ) do
#       { :ok, new_child_generator, result } ->
#         if Enum.member?( locked_states, result ) do
#           # This result is already occupied in the locked_states, will
#           # not calculate further.
#           emitter
#           |> Map.put( :child_generator, new_child_generator )
#           |> walk
#         else
#           # IO.puts "-> got child result"
#           emitter
#           |> Map.put( :child_generator, new_child_generator )
#           |> Map.put( :child_result, result )
#           # |> IO.inspect
#           |> walk
#         end
#       _ ->
#         # IO.puts "-> no child result"
#         emitter
#         |> Map.put( :direction, :up )
#         |> Map.put( :child_result, {:fail} )
#         # |> IO.inspect
#         |> walk
#     end
#   end

#   # going downward with a result means creating a new SomeEmitter for
#   # our downwards walking, and updating our generator so it will
#   # recycle when being called by the child.
#   def walk( %SomeEmitter{ direction: :down,
#                           child_result: child_result,
#                           state: state,
#                           element: element,
#                           base_result: base_result,
#                           locked_states: locked_states,
#                           locked_solution_results: locked_results,
#                           parent_generators: gs } = emitter ) do
#     # IO.puts "walking down"
#     %{ leftover: leftover } = child_result
#     new_state = %{ state | chars: leftover }

#     our_new_emitter = %{ emitter | direction: :up }

#     walk(
#       %SomeEmitter{
#         state: new_state,
#         element: element,
#         locked_states: [ child_result | locked_states ],
#         locked_solution_results: [ base_result( emitter ) | locked_results ],
#         parent_generators: [our_new_emitter | gs],
#         base_result: Result.combine_results( base_result, child_result )
#       } )
#   end

#   # end state is achieved when going up, with no further parent
#   # generators and no result
#   def walk( %SomeEmitter{ direction: :up,
#                           child_result: {:fail},
#                           locked_solution_results: locked_results,
#                           parent_generators: [],
#                         } = emitter ) do
#     new_result = base_result( emitter )

#     if Enum.member?( locked_results, new_result ) do
#       {:fail}
#     else
#       { :ok, %InterpreterTerms.Nothing{}, base_result( emitter ) }
#     end
#   end

#   # reiterate child if there are no parents, but we have a result.
#   def walk( %SomeEmitter{ direction: :up,
#                           child_result: child_result,
#                           base_result: base_result,
#                           locked_solution_results: locked_results,
#                           parent_generators: [] } = emitter ) do
#     new_result = combined_result( emitter )
#     new_emitter = %{ emitter |
#                      child_result: :none,
#                      locked_solution_results: [ new_result | locked_results ], # only necessary for else case
#                      direction: :down }
#     if Enum.member?( locked_results, new_result ) do
#       walk new_emitter
#     else
#       # IO.puts "going up with no parents"
#       { :ok, new_emitter, new_result }
#     end
#   end

#   # when jumping up, and our child had no result, we have to jump
#   # further up
#   def walk( %SomeEmitter{ direction: :up,
#                           child_result: {:fail},
#                           parent_generators: [g|_] } ) do
#     # IO.puts "going up with a parent, but no child result"
#     # IO.inspect g
#     walk( g )
#   end

#   # when jumping up with a result, we can emit the current
#   # child_result, and reuse the logic of an unitiated child_result
#   def walk( %SomeEmitter{ direction: :up,
#                           base_result: base_result,
#                           locked_solution_results: locked_results,
#                           child_result: child_result } = emitter ) do
#     # IO.puts "going up with a parent"
#     combined_result = combined_result( emitter )
#     new_emitter = %{ emitter |
#                      child_result: :none,
#                      direction: :down,
#                      locked_solution_results: [ combined_result | locked_results ] # only necessary for else case
#                    }

#     if Enum.member?( locked_results, combined_result ) do
#       walk new_emitter
#     else
#       { :ok, new_emitter, combined_result }
#     end
#   end

#   defp emit( alpha ) do
#     EbnfParser.Generator.emit( alpha )
#   end

#   defp dispatch_generation( alpha , beta ) do
#     EbnfParser.GeneratorConstructor.dispatch_generation( alpha, beta )
#   end

#   defp base_result( %SomeEmitter{ state: %State{ chars: chars } } ) do
#     %Result{ leftover: chars }
#   end

#   defp combined_result( %SomeEmitter{ child_result: child_result } = emitter ) do
#     combined_result( emitter, child_result )
#   end

#   defp combined_result( %SomeEmitter{ base_result: base_result }, child_result ) do
#     Result.combine_results( base_result, child_result )
#   end

# end
