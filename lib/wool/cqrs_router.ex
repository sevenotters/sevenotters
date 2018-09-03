defmodule Seven.CqrsRouter do
  @moduledoc false

  defmacro __using__(command_router: command_router, query_router: query_router) do
    quote location: :keep do
      use Plug.Router
      alias Plug.Conn.Status

      plug(Plug.Logger)
      plug(CORSPlug)

      plug(:match)
      plug(:dispatch)

      # forward "/command", to: Seven.EndpointCommandRouter
      # forward "/query", to: Seven.EndpointQueryRouter
      forward("/command", to: unquote(command_router))
      forward("/query", to: unquote(query_router))
    end
  end
end
