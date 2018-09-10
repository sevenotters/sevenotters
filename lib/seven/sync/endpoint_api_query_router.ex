defmodule Seven.Sync.EndpointApiQueryRouter do
  defmacro __using__(conn: conn, posts: posts) do
    quote location: :keep do
      use Plug.Router

      @moduledoc false

      alias Plug.Conn.Status
      alias Seven.Sync.ApiRequest

      plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Poison)
      plug(CORSPlug)

      plug(:match)
      plug(:dispatch)

      unquote do
        posts
        |> Enum.map(fn p ->
          quote do
            post "/" <> unquote(p).query do
              unquote(p).module.run(unquote(conn))
              |> send_response(unquote(conn))
            end
          end
        end)
      end

      match _ do
        unquote(conn)
        |> put_resp_header("content-type", "application/json")
        |> send_resp(Status.code(:not_found), "query_not_found")
      end

      defp send_response(%ApiRequest{state: :managed, response: data}, conn) do
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(Status.code(:ok), encode(data))
      end

      defp send_response(%ApiRequest{state: {:unauthorized, reason}}, conn) do
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(Status.code(:unauthorized), encode(%{error: reason}))
      end

      defp send_response(%ApiRequest{state: {:routed_but_invalid, reason}}, conn) do
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(Status.code(:bad_request), encode(%{error: reason}))
      end

      defp send_response(%ApiRequest{state: :query_not_found}, conn) do
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(Status.code(:not_found), encode(%{error: "query_not_found"}))
      end

      defp send_response(%ApiRequest{state: {:resource_not_found, reason}}, conn) do
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(Status.code(:not_found), encode(%{error: reason}))
      end

      @spec encode(Map.t()) :: String.t()
      defp encode(m), do: Poison.encode!(m)
    end
  end
end
