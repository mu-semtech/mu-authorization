alias Generator.State, as: State
alias InterpreterTerms.Array, as: Array
alias InterpreterTerms.Word, as: Word
alias InterpreterTerms.Choice, as: Choice
alias InterpreterTerms.Some, as: Some
alias InterpreterTerms.Many, as: Many
alias InterpreterTerms.Bracket, as: Bracket
alias InterpreterTerms.NotBracket, as: NotBracket
alias InterpreterTerms.Minus, as: Minus
alias InterpreterTerms.Symbol, as: Symbol
alias InterpreterTerms.Maybe, as: Maybe
alias InterpreterTerms.HexCharacter, as: HexCharacter
alias InterpreterTerms.Regex, as: RegexTerm

alias EbnfParser.GeneratorProtocol, as: GP

defmodule EbnfParser.GeneratorConstructor do
  require Logger
  require ALog

  def dispatch_generation( list, %State{} = state ) when is_list( list ) do
    dispatch_generation( { :paren_group, list }, state )
  end

  def dispatch_generation( [{_,_} = spec], %State{} = state ) do
    dispatch_generation( spec, state )
  end

  def dispatch_generation( { :paren_group, items }, %State{} = state ) do
    GP.make_generator( %Array{ elements: items, state: state } )
  end

  def dispatch_generation( { :maybe_many, [item] }, %State{} = state ) do
    GP.make_generator( %Some{ element: item, state: state } )
  end

  def dispatch_generation( { :one_or_more, [item] }, %State{} = state ) do
    GP.make_generator( %Many{ element: item, state: state } )
  end

  def dispatch_generation( { :bracket_selector, items }, %State{} = state ) do
    GP.make_generator( %Bracket{ options: items, state: state } )
  end

  def dispatch_generation( { :not_bracket_selector, items }, %State{} = state ) do
    GP.make_generator( %NotBracket{ options: items, state: state } )
  end

  def dispatch_generation( { :minus, [ left, right ] }, %State{} = state ) do
    GP.make_generator( %Minus{ left: left, right: right, state: state } )
  end

  def dispatch_generation( { :symbol, symbol }, %State{} = state ) do
    GP.make_generator( %Symbol{ symbol: symbol, state: state } )
  end

  def dispatch_generation( { :maybe, [ spec ] }, %State{} = state ) do
    GP.make_generator( %Maybe{ spec: spec, state: state } )
  end

  def dispatch_generation( { :hex_character, number }, %State{} = state ) do
    GP.make_generator( %HexCharacter{ number: number , state: state } )
  end

  # def dispatch_generation( items, %State{} = state ) when is_list( items ) do
  #   make_generator( %Array{ spec: items, state: state } )
  # end

  def dispatch_generation( { :one_of, elements }, %State{} = state ) do
    GP.make_generator( %Choice{ options: elements, state: state } )
  end

  def dispatch_generation( { :regex, regex }, %State{} = state ) do
    GP.make_generator( %RegexTerm{ regex: regex, state: state } )
  end

  def dispatch_generation( { string_type, string }, %State{} = state ) when string_type in [ :single_quoted_string, :double_quoted_string ] do
    GP.make_generator( %Word{ word: string, state: state } )
  end

  def dispatch_generation( a, b ) do
    Logger.warn( "falling back to failed dispatch generation" )
    ALog.di a, "failed dispatch type"
    ALog.di b, "failed dispatch state"
    %InterpreterTerms.Nothing{}
  end
end
