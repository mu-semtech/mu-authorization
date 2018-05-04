defprotocol Regen.Protocol.Generator do
  @type t :: struct()

  @doc "Constructs a new regen generator"

  @spec make_generator( Regen.Protocol.Generator.t ) :: Regen.Generator.t
  def make_generator( generator )
end

defprotocol Regen.Protocol do
  @type t :: struct()
  @type generator :: struct()
  @type result :: struct()
  @type response :: { :ok, Regen.Protocol.generator, Regen.Protocol.result } | { :fail }

  @doc "Emits a new result"
  @spec emit( Regen.Protocol.Generator.t ) :: Regen.Protocol.response
  def emit( generator )
end
