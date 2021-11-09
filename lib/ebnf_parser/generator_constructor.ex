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
    to_term(x)
  end

  def to_term(list) when is_list(list) do
    to_term({:paren_group, list})
  end

  def to_term([{_, _} = spec]) do
    to_term(spec)
  end

  def to_term({:paren_group, items}) do
    %Array{elements: items}
  end

  def to_term({:maybe_many, [item]}) do
    %Some{element: item}
  end

  def to_term({:one_or_more, [item]}) do
    %Many{element: item}
  end

  def to_term({:bracket_selector, items}) do
    %Bracket{options: items}
  end

  def to_term({:not_bracket_selector, items}) do
    %NotBracket{options: items}
  end

  def to_term({:minus, [left, right]}) do
    %Minus{left: left, right: right}
  end

  def to_term({:symbol, symbol}) do
    %Symbol{symbol: symbol}
  end

  def to_term({:maybe, [spec]}) do
    %Maybe{spec: spec}
  end

  def to_term({:hex_character, number}) do
    %HexCharacter{number: number}
  end

  # def dispatch_generation( items ) when is_list( items ) do
  #   make_generator( %Array{ spec: items } )
  # end

  def to_term({:one_of, elements}) do
    %Choice{options: elements}
  end

  def to_term({:regex, regex}) do
    %RegexTerm{regex: regex}
  end

  def to_term({string_type, string})
      when string_type in [:single_quoted_string, :double_quoted_string] do
    %Word{word: string}
  end

  def to_term(a, b) do
    Logger.warn("falling back to create Term")
    ALog.di(a, "failed dispatch type")
    ALog.di(b, "failed dispatch state")
    nil
  end
end
