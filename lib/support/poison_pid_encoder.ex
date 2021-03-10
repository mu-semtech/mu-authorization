defmodule PoisonPIDEncoder do
  alias Poison.Encoder

  defimpl Encoder, for: PID do
    def encode(data, _options) do
      "\"#{inspect(data)}\""
    end
  end
end
