defprotocol EbnfParser.GeneratorProtocol do
  @type t :: struct()

  @doc "Constructs a new generator"
  @spec make_generator( EbnfParser.GeneratorProtocol.t ) :: EbnfParser.Generator.t
  def make_generator( generator )
end

defprotocol EbnfParser.Generator do
  @type t :: struct()
  @type response :: { :ok, EbnfParser.Generator.t, %Generator.Result{} } | { :fail }

  @doc "Emits a new result"
  @spec emit(EbnfParser.Generator.t) :: EbnfParser.Generator.response
  def emit( generator )
end

