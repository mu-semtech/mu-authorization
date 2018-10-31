defmodule EbnfParser.Sparql do
  require Logger
  require ALog
  use GenServer

  @moduledoc """
  Parser which allows you to efficiently fetch the parsed spraql
  syntax.
  """
  @spec split_single_form(String.t, boolean) :: { atom, { boolean, any } }

  @type syntax :: %{ optional( atom ) => any }

  ### GenServer API
  @doc """
    GenServer.init/1 callback
  """
  def init(_) do
    {:ok, EbnfParser.Sparql.parse_sparql}
  end

  @doc """
    GenServer.handle_call/3 callback
  """
  def handle_call(:get, _from, syntax) do
    {:reply, syntax, syntax}
  end

  ### Client API / Helper functions
  def start_link(state\\%{}) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def syntax do
    GenServer.call( __MODULE__, :get )
  end

  def split_single_form( string, terminal\\false ) do
    split_string = String.split( string , "::=", parts: 2 )
    [name, clause] = Enum.map( split_string , &String.trim/1 )
    { String.to_atom( name ), {terminal, full_parse( clause )} }
  end

  def full_parse( string ) do
    EbnfParser.Parser.tokenize_and_parse( string )
  end

  def split_forms( forms ) do
    Enum.map( forms, &split_single_form/1 )
  end

  @spec parse_sparql() :: syntax
  def parse_sparql() do
    %{non_terminal: non_terminal_forms, terminal: terminal_forms} = EbnfParser.Forms.sparql

    non_terminal_map =
      non_terminal_forms
      |> Enum.map( fn x -> split_single_form( x, false ) end )
      |> Enum.into( %{} )

    full_syntax_map =
      terminal_forms
      |> Enum.map( fn x -> split_single_form( x, true ) end )
      |> Enum.into( non_terminal_map )

    _regexp_empowered_map =
      full_syntax_map
      |> augment_with_regexp_terminators
  end

  def augment_with_regexp_terminators( map ) do
    map
    |> Map.put( :STRING_LITERAL_LONG2, {true, [ regex: ~r/^"""(""|")?([^\\"]|(\\[tbnrf"'\\]))*"""/m ]} )
  end



end
