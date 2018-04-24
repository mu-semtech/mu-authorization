alias Generator.State, as: State
alias Generator.Result, as: Result
alias InterpreterTerms.Array.Interpreter, as: ArrayEmitter
import EbnfParser.Generator, only: [emit: 1]
import EbnfParser.GeneratorConstructor, only: [dispatch_generation: 2]

defmodule ArrayEmitter do
  defstruct [ elements: [], state: %State{}, child_generator: :none, rest_generator: :none, last_child_result: %Result{} ]

  # Generator protocol implementation dispatches to walk
  defimpl EbnfParser.Generator do
    def emit( %ArrayEmitter{} = emitter ) do
      ArrayEmitter.walk( emitter )
    end
  end

  # there are no elements
  def walk( %ArrayEmitter{ child_generator: :none, elements: [] } ) do
    { :fail }
  end

  # there is one element
  def walk( %ArrayEmitter{ child_generator: :none, elements: [element], state: state } = emitter ) do
    # 1. make rest generator
    rest_generator = dispatch_generation( element, state )
    # 2. get the result
    case emit( rest_generator ) do
      # 3. emit the result with our new state
      { :ok, generator, result } ->
        new_state = %{ emitter | child_generator: generator }
        { :ok, new_state, result }
      _ -> { :fail }
    end
  end

  def walk( %ArrayEmitter{ child_generator: generator, elements: [_] } = emitter ) do
    # 1. Get a result from the generator
    case emit( generator ) do
      { :ok, new_generator, result } ->
        # 2. emit the result with our new state
        new_state = %{ emitter | child_generator: new_generator }
        { :ok, new_state, result }
      _ -> { :fail }
    end
  end

  def walk( %ArrayEmitter{ rest_generator: :none,
                           child_generator: :none,
                           elements: [e|_],
                           state: state } = emitter ) do
    # 1. make child generator
    child_generator = dispatch_generation( e, state )
    # 2. disptach to regular circuit for rebuilding children
    walk( %{ emitter | child_generator: child_generator } )
  end

  def walk( %ArrayEmitter{ rest_generator: :none,
                           child_generator: child_generator,
                           elements: [_|es],
                           state: state } = emitter ) do
    # 2. get result from our child generator
    case emit( child_generator ) do
      # 3. is there a result?
      { :ok, new_child_generator, %Result{ leftover: leftover } = child_result } ->
        # 3.y.1 construct ArrayEmitter generator for children
        rest_generator =
          %ArrayEmitter{
            elements: es,
            state: %{ state | chars: leftover },
            last_child_result: child_result
          }
        walk( %{ emitter | rest_generator: rest_generator, child_generator: new_child_generator } )
      _ ->
        # 3.n there are no more results in this branch
        { :fail }
    end
  end

  def walk( %ArrayEmitter{ rest_generator: rest_generator, last_child_result: child_result } = emitter ) do
    # 3.y.2 get a result from the rest generator
    case emit( rest_generator ) do
      # 3.y.3 is there a result?
      { :ok, new_rest_generator, rest_result } ->
        # 3.y.3.y.1 combine the result with our child's latest result (assuming that exists)
        combined_result = combine_results( child_result, rest_result )
        # 3.y.3.y.2 build our new state, replacing the rest_generator
        new_state = %{ emitter |
                       rest_generator: new_rest_generator }
        # 3.y.3.y.3 emit the result
        { :ok, new_state, combined_result }
      # 3.y.3.n continue walking, assuming no rest generator
      _ -> walk( %{ emitter | rest_generator: :none } )
    end
  end

  @doc """
  Combines two results for a list match.
  The first supplied result is the one that was generated earlier.
  """
  defp combine_results( base_result, new_result ) do
    %Result{ matched_string: base_str, match_construct: base_match } = base_result
    %Result{ matched_string: new_str, match_construct: new_match, leftover: leftover } = new_result

    %Result{
      matched_string: base_str <> new_str,
      match_construct: base_match ++ new_match,
      leftover: leftover
    }
  end

end

