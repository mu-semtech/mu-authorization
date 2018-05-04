defmodule Regen.Processors.None do
  defstruct []

  defimpl Regen.Protocol do
    def emit( %Regen.Processors.None{} ) do
      { :fail }
    end
  end

end
