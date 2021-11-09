defprotocol EbnfParser.ParserProtocol do
  @type t :: any
  @type parser :: struct()

  @spec make_parser(EbnfParser.ParserProtocol.t()) :: EbnfParser.ParserProtocol.parser()
  def make_parser(interpreter_terms)
end

defprotocol EbnfParser.ParseProtocol do
  @type parsers :: %{required(atom()) => {EbnfParser.ParserProtocol.parser(), boolean}}
  @type success :: Generator.Result.t()
  @type failure :: Generator.Error.t()
  @type response :: [success | failure]

  @spec parse(EbnfParser.ParserProtocol.parser(), parsers(), [String.grapheme()]) ::
          EbnfParser.ParseProtocol.response()
  def parse(parser, parsers, chars)
end
