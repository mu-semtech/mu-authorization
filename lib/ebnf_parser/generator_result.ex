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

  @doc """
  Extracts a single match_construct element from the result.
  This tends to be the interesting information for a SPARQL query.
  """
  def extract_element( %Generator.Result{ match_construct: [element] } ) do
    element
  end

  @doc """
  Yields truethy when the supplied result is a full match which consumed all
  available characters.
  """
  def full_match?( %Generator.Result{ leftover: [] } ) do
    true
  end
  def full_match?( %Generator.Result{} ) do
    false
  end

end
