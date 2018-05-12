defprotocol Regen.Protocol do
  @type t :: struct()
  @type generator :: struct()
  @type state :: struct()
  @type response :: { :ok, Regen.Protocol.generator, Regen.Protocol.state } | { :fail }

  @doc "Emits a new result"
  @spec emit( Regen.Protocol.generator ) :: Regen.Protocol.response
  def emit( generator )
end
