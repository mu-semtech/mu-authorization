defprotocol EbnfParser.GeneratorProtocol do
  @type t :: struct()

  @doc "Constructs a new generator (generator like parser)"
  @spec make_generator(EbnfParser.GeneratorProtocol.t()) :: EbnfParser.Generator.t()
  def make_generator(generator)
end

defprotocol EbnfParser.ParserProtocol do
  @type t :: any
  @type parser :: struct()

  @spec make_parser(EbnfParser.ParserProtocol.t(), EbnfParser.Sparql.syntax()) ::
          EbnfParser.ParserProtocol.parser()
  def make_parser(interpreter_terms, syntax)
end

defprotocol EbnfParser.ParseProtocol do
  @spec parse(EbnfParser.ParserProtocol.parser(), [String.grapheme()]) ::
          [Generator.Result.t()] | {:fail}
  def parse(parser, chars)
end

defprotocol EbnfParser.Generator do
  @type t :: struct()
  @type response :: {:ok, EbnfParser.Generator.t(), Generator.Result.t()} | {:fail}

  @doc "Emits a new result"
  @spec emit(EbnfParser.Generator.t()) :: EbnfParser.Generator.response()
  def emit(generator)
end
