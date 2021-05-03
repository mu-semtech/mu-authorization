defmodule Logging.EnvLog do
  @moduledoc """
  Configurable logging methods, based on user configuration.
  """

  @doc """
  Conditional variant of IO.log/1.  First argument is the environment
  variable to check, second is the string to log.
  """
  def log(name, content) do
    if Application.get_env(:"mu-authorization", name) do
      IO.puts(content)
    else
      :ok
    end
  end

  @doc """
  Conditional variant of IO.inspect/2.  First argument is the entity to
  inspect, second is the condition to check, the rest are options for
  IO.inspect.
  """
  def inspect(content, name, opts \\ []) do
    if Application.get_env(:"mu-authorization", name) do
      IO.inspect(content, opts)
    else
      content
    end
  end
end
