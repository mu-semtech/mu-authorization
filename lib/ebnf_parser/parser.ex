defmodule EbnfParser.Parser do

  def ebnf_parser_reverse_order( { name, [ a | rest ]  } ) do
    updated_content =
      [ a | rest ]
      |> Enum.reverse
      |> (Enum.map &ebnf_parser_reverse_order/1 )
    { name, updated_content}
  end

  def ebnf_parser_reverse_order( { name, content } ) do
    { name, content}
  end

  def ebnf_parser_reverse_order( item ) do
    item
  end

  def ebnf_parser_append_to_parent( content, [ { parent_group, parent_content } | other_parents ] ) do
    [ { parent_group, [ content | parent_content ] } | other_parents ]
  end

  # Parser for EBNF syntax
  # Groups logical syntax so it's easy to understand
  #
  def ebnf_parser( tokens ) do
    ebnf_parser( tokens, [{:root, []} ] )
  end

  def ebnf_parser( [], [{:root, scans}] ) do
    scans
  end

  ## Parentheses
  # { :open_paren }
  def ebnf_parser( [ { :open_paren } | other_input ], rest ) do
    ebnf_parser( other_input, [ { :paren_group, [] } | rest ] )
  end

  # { :pipe }
  def ebnf_parser( [ { :pipe } | rest ], [ { parent_type, [ left_sibling | other_siblings ] } | other_parents ] ) do
    ebnf_parser( rest, [ { :one_of, [ left_sibling ] }, { parent_type, other_siblings } | other_parents ] )
  end

  def ebnf_parser( content, [ { :one_of, [ left_sibling, right_sibling ] }, { :one_of, siblings } | other_parents ] ) do
    ebnf_parser( content, [ { :one_of, [ left_sibling, right_sibling | siblings ] } | other_parents ] )
  end

  def ebnf_parser( content, [ { :one_of, [ left_sibling, right_sibling | other_siblings ] } , { parent_type, other_parent_siblings } | other_parents] ) do
    ebnf_parser( content, [ { parent_type, [ { :one_of, [ left_sibling, right_sibling | other_siblings ] } | other_parent_siblings ] } | other_parents ] )
  end

  # { :minus }
  def ebnf_parser( [ { :minus } | rest ], [ { parent_type, [ left_sibling | other_siblings ] } | other_parents ] ) do
    ebnf_parser( rest, [ { :minus, [ left_sibling ] }, { parent_type, other_siblings } | other_parents ] )
  end

  def ebnf_parser( content, [ { :minus, [ left_sibling, right_sibling ] } , { parent_type, other_siblings } | other_parents] ) do
    ebnf_parser( content, [ { parent_type, [ { :minus, [ left_sibling, right_sibling ] } | other_siblings ] } | other_parents ] )
  end

  # { :range }
  def ebnf_parser( [ { :range } | rest ], [ { parent_type, [ left_sibling | other_siblings ] } | other_parents ] ) do
    ebnf_parser( rest, [ { :range, [ left_sibling ] }, { parent_type, other_siblings } | other_parents ] )
  end

  def ebnf_parser( content, [ { :range, [ left_sibling, right_sibling ] } , { parent_type, other_siblings } | other_parents] ) do
    ebnf_parser( content, [ { parent_type, [ { :range, [ left_sibling, right_sibling ] } | other_siblings ] } | other_parents ] )
  end

  # { :close_paren }
  def ebnf_parser([ { :close_paren } | other_input ], [ { :paren_group, content }, { parent_group, parent_content } | other_parents ] ) do
    ebnf_parser( other_input, [ { parent_group, [ { :paren_group, content } | parent_content ] } | other_parents ] )
  end

  # { :open_bracket }
  def ebnf_parser( [ { :open_bracket }, { :negation } | other_input ], parents ) do
    ebnf_parser( other_input, [ { :not_bracket_selector, [] } | parents ] )
  end

  def ebnf_parser( [ { :open_bracket } | other_input ], parents ) do
    ebnf_parser( other_input, [ { :bracket_selector, [] } | parents ] )
  end

  # { :close_bracket }
  def ebnf_parser(
    [ { :close_bracket } | other_input ],
    [ { bracket_type, content }, { parent_group, first_parent_content } | other_parents ] ) do

    ebnf_parser( other_input, [ { parent_group, [ { bracket_type, content } | first_parent_content ] } | other_parents ] )
  end

  # { :character, char }
  def ebnf_parser( [ { :character, char } | other_input ], parents ) do
    ebnf_parser( other_input, ebnf_parser_append_to_parent( { :character, char }, parents ) )
  end

  # { :comment }
  def ebnf_parser( [ { :comment , _string } | rest ], parent_content ) do
    ebnf_parser( rest, parent_content )
  end

  # { :symbol, string }
  def ebnf_parser( [ { :symbol, string } | rest ], parents ) do
    ebnf_parser( rest, ebnf_parser_append_to_parent( { :symbol, string }, parents ) )
  end

  # { :double_quote, string }
  def ebnf_parser( [ { :double_quote, string } | rest ], parents ) do
    ebnf_parser( rest, ebnf_parser_append_to_parent( { :double_quoted_string, string }, parents ) )
  end

  # { :single_quote, string }
  def ebnf_parser( [ { :single_quote, string } | rest ], parents ) do
    ebnf_parser( rest, ebnf_parser_append_to_parent( { :single_quoted_string, string }, parents ) )
  end

  # { :hex_character, value }
  def ebnf_parser( [ { :hex_character, value } | rest ], parents ) do
    ebnf_parser( rest, ebnf_parser_append_to_parent( { :hex_character, value }, parents ) )
  end

  # { :question_mark }
  def ebnf_parser( [ { :question_mark } | rest ], [ { parent_group, [ first_elt | rest_elts ] } | parents ] ) do
    ebnf_parser( rest, [ { parent_group, [ { :maybe, [ first_elt ] } | rest_elts ] } | parents ] )
  end

  # { :star }
  def ebnf_parser( [ { :star } | rest ], [ { parent_group, [ first_elt | rest_elts ] } | parents ] ) do
    ebnf_parser( rest, [ { parent_group, [ { :maybe_many, [ first_elt ] } | rest_elts ] } | parents ] )
  end

  # { :plus }
  def ebnf_parser( [ { :plus } | rest ], [ { parent_group, [ first_elt | rest_elts ] } | parents ] ) do
    ebnf_parser( rest, [ { parent_group, [ { :one_or_more, [ first_elt ] } | rest_elts ] } | parents ] )
  end
  
  def ebnf_tokenizer( _, [] ) do
    []
  end
  
end
