defmodule SparqlServer.Router.Handler.Worker do
  require Logger
  require ALog
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  def init(_) do
    {:ok, %{ template_store: %{} }}
  end

  def handle_call({:handle_query, query_string, kind, conn}, _from, local_template_store) do
    { conn, encoded_response, new_local_template_store } =
      SparqlServer.Router.HandlerSupport.handle_query_with_template_local_store( query_string, kind, conn, local_template_store )

    {:reply, { conn, encoded_response }, new_local_template_store}
  end
end
