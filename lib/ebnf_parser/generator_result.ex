defmodule Generator.Result do
  defstruct leftover: [], matched_string: "", match_construct: []

  def length( %Generator.Result{ matched_string: str } ) do
    String.length( str )
  end
end
