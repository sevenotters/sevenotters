defmodule Seven.Endpoint do
  use Seven.CqrsRouter,
    command_router: Seven.EndpointCommandRouter,
    query_router: Seven.EndpointQueryRouter

  match _ do
    send_resp(conn, Status.code(:not_found), "Resource not found.")
  end
end
