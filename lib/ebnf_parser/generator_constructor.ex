alias Generator.State, as: State
alias InterpreterTerms.Array, as: Array
alias InterpreterTerms.Word, as: Word
alias InterpreterTerms.Choice, as: Choice

alias EbnfParser.GeneratorProtocol, as: GP

defmodule EbnfParser.GeneratorConstructor do
  # def dispatch_generation( { :paren_group, items }, %State{} = state ) do
  #   GP.make_generator( %Array{ spec: items, state: state } )
  # end

  # def dispatch_generation( items, %State{} = state ) when is_list( items ) do
  #   make_generator( %Array{ spec: items, state: state } )
  # end

  def dispatch_generation( { :one_of, elements }, %State{} = state ) do
    GP.make_generator( %Choice{ options: elements, state: state } )
  end

  def dispatch_generation( { string_type, string }, %State{} = state ) when string_type in [ :single_quoted_string, :double_quoted_string ] do
    IO.inspect GP.make_generator( %Word{ word: string, state: state } )
  end

  def dispatch_generation( _, _ ) do
    IO.puts "falling back to failed dispatch generation"
    %InterpreterTerms.Nothing{}
  end
end
