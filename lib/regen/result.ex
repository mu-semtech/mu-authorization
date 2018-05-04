defmodule Regen.Result do
  defstruct [ :status ]

  def all( generator, emitter \\ &Regen.Protocol.emit/1, results \\ [] ) do
    case emitter.(generator) do
      { :ok, new_generator, new_result } ->
        all( new_generator, emitter, [ new_result | results ] )
      { _ } ->
        Enum.reverse( results )
    end

  end

end
