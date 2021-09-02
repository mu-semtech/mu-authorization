defprotocol EbnfParser.GeneratorProtocol do
  @type t :: struct()

  @doc "Constructs a new generator (generator like parser)"
  @spec make_generator(EbnfParser.GeneratorProtocol.t()) :: EbnfParser.Generator.t()
  def make_generator(generator)
end

defprotocol EbnfParser.ParserProtocol do
  @type t :: any
  @type parser :: struct()

  @spec make_parser(EbnfParser.ParserProtocol.t()) :: EbnfParser.ParserProtocol.parser()
  def make_parser(interpreter_terms)
end

defprotocol EbnfParser.ParseProtocol do
  @type parsers :: %{required(atom()) => EbnfParser.ParserProtocol.parser()}
  @type success :: Generator.Result.t()
  @type failure :: {:failed, any()}
  @type response :: [success | failure]

  @spec parse(EbnfParser.ParserProtocol.parser(), parsers(), [String.grapheme()]) ::
          EbnfParser.ParseProtocol.response()
  def parse(parser, parsers, chars)
end

defprotocol EbnfParser.Generator do
  @type t :: struct()
  @type response :: {:ok, EbnfParser.Generator.t(), Generator.Result.t()} | {:fail}

  @doc "Emits a new result"
  @spec emit(EbnfParser.Generator.t()) :: EbnfParser.Generator.response()
  def emit(generator)
end
