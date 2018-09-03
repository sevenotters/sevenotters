defmodule Seven.EndpointCommandRouter do
  use Plug.Router

  @moduledoc false

  alias Plug.Conn.Status

  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Poison)
  plug(CORSPlug)

  plug(:match)
  plug(:dispatch)

  post "/:command" do
    res =
      %Seven.CommandRequest{
        id: Seven.Data.Persistence.new_id(),
        command: command,
        sender: __MODULE__,
        params: AtomicMap.convert(conn.params)
      }
      |> Seven.Log.command_request_sent()
      |> Seven.CommandBus.send_command_request()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(send_status(res), send_body(res))
  end

  match _ do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(send_status({:not_managed}), send_body({:not_managed}))
  end

  # Privates
  defp send_status({:managed}), do: Status.code(:ok)
  defp send_status({:routed_but_invalid, _}), do: Status.code(:bad_request)
  defp send_status({:not_managed}), do: Status.code(:not_found)
  defp send_status(_), do: Status.code(:not_found)

  defp send_body({:managed}), do: ""
  defp send_body({:routed_but_invalid, reason}), do: Poison.encode!(reason)
  defp send_body({:not_managed}), do: "Command not found."
  defp send_body(_), do: "Unknown error."
end
