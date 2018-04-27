alias Generator.State, as: State
alias Generator.Result, as: Result
alias InterpreterTerms.Some.Interpreter, as: SomeEmitter
# import EbnfParser.Generator, only: [emit: 1]
# import EbnfParser.GeneratorConstructor, only: [dispatch_generation: 2]

defmodule SomeEmitter do
  defstruct [ :element, :state,
              { :child_generator, :none }, # generator for our step in
                                           # the downward cycle.
              { :child_result, :none }, # contains the result of our
                                        # child, for combinatory
                                        # purposes.
              { :parent_generators, [] }, # parent generators are all
                                          # %SomeEmitter{}.
              { :base_result, %Result{} }, # result supplied by our
                                           # parents so we can
                                           # directly emit a correct
                                           # result.
              { :direction, :down } ] # :down means applying pattern
                                      # more times, :up means applying
                                      # less times (each jump up emits
                                      # results).  When jumping up, we
                                      # setup the next generator (down
                                      # if we have a next state, up
                                      # otherwise), and emit the
                                      # current result.
  
  defimpl EbnfParser.Generator do
    def emit( %SomeEmitter{} = emitter ) do
      emitter
      |> SomeEmitter.walk
    end
  end


  # initialize the child generator
  def walk( %SomeEmitter{ child_generator: :none, element: element, state: state, direction: :down } = emitter ) do
    # IO.puts "initialize the child generator"
    # IO.inspect element
    emitter
    |> Map.put( :child_generator, dispatch_generation( element, state ) )
    # |> IO.inspect
    |> walk
  end

  # initialize the child generator's first result
  def walk( %SomeEmitter{ child_generator: g, child_result: :none, direction: :down } = emitter ) do
    # IO.puts "initialize the child generator's first result"
    case emit( g ) do
      { :ok, new_child_generator, result } ->
        # IO.puts "-> got child result"
        emitter
        |> Map.put( :child_generator, new_child_generator )
        |> Map.put( :child_result, result )
        # |> IO.inspect
        |> walk
      _ ->
        # IO.puts "-> no child result"
        emitter
        |> Map.put( :direction, :up )
        |> Map.put( :child_result, {:fail} )
        # |> IO.inspect
        |> walk
    end
  end

  # going downward with a result means creating a new SomeEmitter for
  # our downwards walking, and updating our generator so it will
  # recycle when being called by the child.
  def walk( %SomeEmitter{ direction: :down,
                          child_result: child_result,
                          state: state,
                          element: element,
                          base_result: base_result,
                          parent_generators: gs } = emitter ) do
    # IO.puts "walking down"
    %{ leftover: leftover } = child_result
    new_state = %{ state | chars: leftover }

    our_new_emitter = %{ emitter | direction: :up }

    walk(
      %SomeEmitter{
        state: new_state,
        element: element,
        parent_generators: [our_new_emitter | gs],
        base_result: Result.combine_results( base_result, child_result )
      } )
  end

  # end state is achieved when going up, with no further parent
  # generators and no result
  def walk( %SomeEmitter{ direction: :up,
                          child_result: {:fail},
                          parent_generators: [],
                          state: %State{ chars: chars }
                        } ) do
    { :ok, %InterpreterTerms.Nothing{}, %Result{ leftover: chars } }
  end

  # reiterate child if there are no parents, but we have a result
  def walk( %SomeEmitter{ direction: :up,
                          child_result: child_result,
                          base_result: base_result,
                          parent_generators: [] } = emitter ) do
    # IO.puts "going up with no parents"
    { :ok,
      %{ emitter |
         child_result: :none,
         direction: :down },
      Result.combine_results( base_result, child_result ) }
  end

  # when jumping up, and our child had no result, we have to jump
  # further up
  def walk( %SomeEmitter{ direction: :up,
                          child_result: {:fail},
                          parent_generators: [g|_] } ) do
    # IO.puts "going up with a parent, but no child result"
    # IO.inspect g
    walk( g )
  end

  # when jumping up with a result, we can emit the current
  # child_result, and reuse the logic of an unitiated child_result
  def walk( %SomeEmitter{ direction: :up,
                          base_result: base_result,
                          child_result: child_result } = emitter ) do
    # IO.puts "going up with a parent"
    { :ok,
      %{ emitter |
         child_result: :none,
         direction: :down
      },
      Result.combine_results( base_result, child_result ) }
  end
                          
  defp emit( alpha ) do
    EbnfParser.Generator.emit( alpha )
  end

  defp dispatch_generation( alpha , beta ) do
    EbnfParser.GeneratorConstructor.dispatch_generation( alpha, beta )
  end

end
