defmodule Seven.EndpointQueryRouter do
  use Plug.Router

  @moduledoc false

  alias Plug.Conn.Status

  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Poison)
  plug(CORSPlug)

  plug(:match)
  plug(:dispatch)

  post "/:query" do
    case Seven.Projections.get_projection(query) do
      {:ok, module} ->
        results = module.filter(fn _ -> true end)

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(Status.code(:ok), Poison.encode!(results))

      {:error, _} ->
        conn |> send_not_found()
    end
  end

  match(_, do: conn |> send_not_found())

  # Privates
  defp send_not_found(conn) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(Status.code(:not_found), "query not found")
  end
end
