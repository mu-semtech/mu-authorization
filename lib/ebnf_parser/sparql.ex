defmodule EbnfParser.Sparql do
  @type syntax :: %{ optional( atom ) => any }

  @moduledoc """
  Parser which allows you to efficiently fetch the parsed spraql
  syntax.
  """
  @spec split_single_form(String.t, boolean) :: { atom, { boolean, any } }
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

    my_map =
      non_terminal_forms
      |> Enum.map( fn x -> split_single_form( x, false ) end )
      |> Enum.into( %{} )

    terminal_forms
    |> Enum.map( fn x -> split_single_form( x, true ) end )
    |> Enum.into( my_map )
  end

  def syntax do
    parse_sparql()
  end

end
