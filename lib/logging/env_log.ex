defmodule Logging.EnvLog do
  def log( name, content ) do
    if Application.get_env( :"mu-authorization", name ) do
      IO.puts( content )
    else
      :ok
    end
  end

  def inspect( content, name, opts \\ [] ) do
    if Application.get_env( :"mu-authorization", name ) do
      IO.inspect( content, opts )
    else
      content
    end
  end
end
