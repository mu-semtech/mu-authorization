defmodule Generator.Result do
  defstruct leftover: [], matched_string: "", match_construct: []

  def length( %Generator.Result{ matched_string: str } ) do
    String.length( str )
  end

  @doc """
  Combines two results for a list match.
  The first supplied result is the one that was generated earlier.
  """
  def combine_results( base_result, new_result ) do
    %Generator.Result{ matched_string: base_str, match_construct: base_match } = base_result
    %Generator.Result{ matched_string: new_str, match_construct: new_match, leftover: leftover } = new_result

    %Generator.Result{
      matched_string: base_str <> new_str,
      match_construct: base_match ++ new_match,
      leftover: leftover
    }
  end
end