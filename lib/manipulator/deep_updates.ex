defmodule Manipulators.DeepUpdates do
  def update_deep_submatch( _match, new_value, [] ) do
    new_value
  end
  def update_deep_submatch( match, new_value, [ { symbol, submatch_number } | rest_spec ] ) do
    # verify the symbol is correct when supplied
    case symbol do
      :_ -> match
      _ -> %{ symbol: ^symbol } = match
    end

    # set the property
    new_submatches =
      match.submatches
      |> update_enum_at( submatch_number, fn (item) -> update_deep_submatch( item, new_value, rest_spec ) end )

    %{ match | submatches: new_submatches }
  end
  def update_deep_submatch( match, new_value, [ symbol | rest_spec ] ) do
    update_deep_submatch( match, new_value, [ {symbol, 0} | rest_spec ] )
  end

  def update_enum_at( enum, index, functor ) do
    enum
    |> Enum.reduce( {0,[]}, fn (element, {current_index, reversed_enum}) ->
      next_index = current_index + 1
      if current_index == index do
        { next_index, [ functor.(element) | reversed_enum ]}
      else
        { next_index, [ element | reversed_enum ] }
      end
    end )
    |> elem(1)
    |> Enum.reverse
  end
end
