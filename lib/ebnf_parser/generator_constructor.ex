defmodule EbnfParser.GeneratorConstructor do
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

  require Logger
  require ALog

  @type(
    ebnf_term ::
      :paren_group
      | :maybe_many
      | :one_or_more
      | :bracket_selector
      | :not_bracket_selector
      | :minus
      | :symbol
      | :maybe
      | :hex_character
      | :one_of
      | :regex
      | :single_quoted_string,
    :double_quoted_string
  )

  @type rule :: list | {ebnf_term, any}
  @spec dispatch_generation(rule, State.t()) :: GP.t()

  def dispatch_generation(alpha, beta) do
    GP.make_generator(to_term(alpha, beta))
  end

  def to_term(x) do
    to_term(x, %State{})
  end

  def to_term(list, %State{} = state) when is_list(list) do
    to_term({:paren_group, list}, state)
  end

  def to_term([{_, _} = spec], %State{} = state) do
    to_term(spec, state)
  end

  def to_term({:paren_group, items}, %State{} = state) do
    %Array{elements: items, state: state}
  end

  def to_term({:maybe_many, [item]}, %State{} = state) do
    %Some{element: item, state: state}
  end

  def to_term({:one_or_more, [item]}, %State{} = state) do
    %Many{element: item, state: state}
  end

  def to_term({:bracket_selector, items}, %State{} = state) do
    %Bracket{options: items, state: state}
  end

  def to_term({:not_bracket_selector, items}, %State{} = state) do
    %NotBracket{options: items, state: state}
  end

  def to_term({:minus, [left, right]}, %State{} = state) do
    %Minus{left: left, right: right, state: state}
  end

  def to_term({:symbol, symbol}, %State{} = state) do
    %Symbol{symbol: symbol, state: state}
  end

  def to_term({:maybe, [spec]}, %State{} = state) do
    %Maybe{spec: spec, state: state}
  end

  def to_term({:hex_character, number}, %State{} = state) do
    %HexCharacter{number: number, state: state}
  end

  # def dispatch_generation( items, %State{} = state ) when is_list( items ) do
  #   make_generator( %Array{ spec: items, state: state } )
  # end

  def to_term({:one_of, elements}, %State{} = state) do
    %Choice{options: elements, state: state}
  end

  def to_term({:regex, regex}, %State{} = state) do
    %RegexTerm{regex: regex, state: state}
  end

  def to_term({string_type, string}, %State{} = state)
      when string_type in [:single_quoted_string, :double_quoted_string] do
    %Word{word: string, state: state}
  end

  def to_term(a, b) do
    Logger.warn("falling back to create Term")
    ALog.di(a, "failed dispatch type")
    ALog.di(b, "failed dispatch state")
    %InterpreterTerms.Nothing{}
  end
end
