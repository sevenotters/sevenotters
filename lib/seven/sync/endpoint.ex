defmodule Seven.Sync.Endpoint do
  use Seven.Sync.CqrsRouter,
    command_router: Seven.Sync.EndpointCommandRouter,
    query_router: Seven.Sync.EndpointQueryRouter

  match _ do
    send_resp(conn, Status.code(:not_found), "Resource not found.")
  end
end
