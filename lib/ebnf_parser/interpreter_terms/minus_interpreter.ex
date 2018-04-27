alias Generator.State, as: State
alias InterpreterTerms.Minus.Interpreter, as: MinusEmitter
# import EbnfParser.Generator, only: [emit: 1]
# import EbnfParser.GeneratorConstructor, only: [dispatch_generation: 2]

defmodule MinusEmitter do
  defstruct [ :left_generator, :right_generator,
              {:left_results, :none}, {:right_results, :none},
              {:combined_results, :none},
              {:state, %State{} } ]

  defp emit( alpha ) do
    EbnfParser.Generator.emit( alpha )
  end

  defp all_results( gen, results \\ [] ) do
    case emit( gen ) do
      { :ok, new_gen, res } ->
        all_results( new_gen, [ res | results ] )
      _ -> results
    end
  end

  defimpl EbnfParser.Generator do
    def emit( %MinusEmitter{} = emitter ) do
      MinusEmitter.walk( emitter )
    end
  end

  def walk( %MinusEmitter{ left_generator: gen, left_results: :none } = emitter ) do
    emitter
    |> Map.put( :left_results, all_results( gen ) )
    |> walk
  end

  def walk( %MinusEmitter{ right_generator: gen, right_results: :none } = emitter ) do
    emitter
    |> Map.put( :right_results, all_results( gen ) )
    |> walk
  end

  def walk( %MinusEmitter{ left_results: left, right_results: right, combined_results: :none } = emitter) do
    [r_left, r_right] = [left, right]
    |> Enum.map( &MapSet.new/1 )
    
    combined_results =
      MapSet.difference( r_left, r_right )
      |> Enum.into( [] )
      |> Enum.sort_by( &Generator.Result.length/1, &<=/2 )

    emitter
    |> Map.put( :combined_results, combined_results )
    |> walk
  end

  def walk( %MinusEmitter{ combined_results: [r | rs] } = emitter ) do
    { :ok, %{ emitter | combined_results: rs }, r }
  end

  def walk( %MinusEmitter{ combined_results: [] } ) do
    { :fail }
  end
end
