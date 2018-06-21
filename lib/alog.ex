defmodule ALog do
  require Logger

  @moduledoc """
  Simpler way to do logging through an inspect-like syntax.
  """

  @doc """
  Works like inspect, but operates on the debug logger, allowing it to
  be pruned.
  """
  def debug_inspect( name, item ) do
    Logger.debug( "#{name}: #{inspect item}" )
  end

  @doc """
  Works like inspect, but is sufficiently smart to never inspect the
  supplied item when debugging.  It just passes the item through.
  Note that the form may be evaluated twice.
  """
  defmacro di( item, name ) do
    quote do
      Logger.debug( fn -> unquote( name ) <> ": " <> inspect( unquote( item ) ) end )
      unquote( item )
    end
  end

  @doc """
  Works like inspect, but is sufficiently smart to never inspect the
  supplied item when going through info.  It just passes the item through.
  Note that the form may be evaluated twice.
  """
  defmacro ii( item, name ) do
    quote do
      Logger.info( fn -> unquote( name ) <> ": " <> inspect( unquote( item ) ) end )
      unquote( item )
    end
  end

end



