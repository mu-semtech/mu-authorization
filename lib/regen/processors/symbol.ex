alias Regen.Processors.Symbol, as: Symbol
alias Regen.Status, as: State
alias InterpreterTerms.SymbolMatch, as: SymbolMatch

# The symbol will firstly fail matching if an incorrect symbol could
# was found in the results.  If the correct symbol was found,
# subresults will be generated for this submatch.
#
# Only results where all of the child-generated submatches are
# consumed, will be returned.  In the emitted results, the strings are
# always pushed on top of the flat "produced_content" property.

defmodule Symbol do
  defstruct [ :symbol, :state, { :ebnf, :none }, {:self_element, :none}, { :sub_generator, :none } ]

  defimpl Regen.Protocol do
    def emit( %Symbol{} = symbol ) do
      Symbol.walk( symbol )
    end
  end

  def walk( %Symbol{} = symbol ) do
    symbol = ensure_self_element( symbol )
    cond do
      no_self_element_found( symbol ) ->
        # if there is no self element, we can't have results
        { :fail }
      is_explicit_leaf_node( symbol ) ->
        { :ok,
          %Regen.Processors.None{},
          state_for_leaf_node( symbol ) }
      next_item_is_correct_symbol( symbol ) ->
        symbol
        # |> ensure_syntax_in_state
        |> ensure_ebnf
        |> ensure_sub_generator
        |> emit_result
      true ->
        { :fail }
    end
  end

  defp ensure_self_element( %Symbol{ self_element: :none,
                                     state: %State{ elements: [first|rest] } = state
                                   } = symbol ) do
    %{ symbol |
       self_element: first,
       state: %{ state | elements: rest } }
  end
  defp ensure_self_element( %Symbol{} = symbol ) do
    symbol
  end

  defp no_self_element_found( %Symbol{ self_element: self_element } ) do
    # should have been set earlier
    self_element == :none
  end


  defp state_for_leaf_node( %Symbol{ state: %State{ produced_content: items } = state,
                                     self_element: %SymbolMatch{ string: string } } ) do
    %{ state | produced_content: [ string | items ] }
  end

  defp is_explicit_leaf_node( %Symbol{ self_element: %SymbolMatch{ submatches: submatches } } ) do
    submatches == :none
  end
  defp is_explicit_leaf_node( _ ) do
    false
  end


  defp next_item_is_correct_symbol( %Symbol{
        symbol: symbol,
        self_element: %SymbolMatch{ symbol: symbol } }) do
    true
  end
  defp next_item_is_correct_symbol( _ ) do
    false
  end

  defp ensure_syntax_in_state( %Symbol{ state: %State{ syntax: :none } = state } = symbol ) do
    %{ symbol |
       state: %{ state | syntax: Parser.parse_sparql } }
  end
  defp ensure_syntax_in_state( symbol ) do
    symbol
  end

  defp ensure_sub_generator( %Symbol{ sub_generator: :none,
                                      ebnf: ebnf,
                                      state: state,
                                      self_element: %SymbolMatch{ submatches: sub_elements }
                                    } = symbol ) do
    # in order to build a generator, we have to know the element on
    # which we're walking.  this element will have `submatches'.  this
    # array will serve as the basis for matching the ebnf beloning to
    # our symbol.
    sub_generator_state = %{ state | elements: sub_elements }
    generator = Regen.Constructor.make( ebnf, sub_generator_state )
    %{ symbol | sub_generator: generator }
  end

  defp ensure_sub_generator( %Symbol{} = symbol ) do
    symbol
  end


  defp ensure_ebnf( %Symbol{ ebnf: :none,
                             # state: %State{ syntax: syntax },
                             symbol: symbol
                           } = symbol_struct ) do
    syntax = Parser.parse_sparql
    { _, ebnf } = Map.get( syntax, symbol )
    %{ symbol_struct | ebnf: ebnf }
  end
  defp ensure_ebnf( %Symbol{} = symbol ) do
    symbol
  end

  defp emit_result( %Symbol{ sub_generator: gen,
                             state: %State{ elements: elements } } = symbol ) do
    # emit a result from our generator.  emit result if all elements
    # are consumed.  iterate if not.
    case Regen.Protocol.emit( gen ) do
      { :ok, new_gen, %State{ elements: [] } = generated_state } ->
        # our child has a state with all necessary elements consumed,
        # we can yield it as a result.
        { :ok,
          %{ symbol | sub_generator: new_gen },
          %{ generated_state | elements: elements } } # yield our own elements in the state
      { :ok, new_gen, _ } ->
        # not all elements were consumed.  retry
        %{ symbol | sub_generator: new_gen }
        |> emit_result
      _ ->
        # we could not find a result, emit failure
        { :fail }
    end
  end

end
