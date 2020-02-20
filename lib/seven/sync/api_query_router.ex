defmodule Seven.Sync.ApiQueryRouter do
  @moduledoc false

  defp is_not_nil(arg), do: not is_nil(arg)

  defmacro __using__(post: post) do
    quote location: :keep do
      alias Seven.Sync.ApiRequest

      @doc false
      def run(conn) do
        %ApiRequest{
          req_headers: conn.req_headers,
          params: conn.params,
          projection: unquote(post).projection,
          filter: unquote(post).filter,
          query: unquote(post).query
        }
        |> crc_signature_checker
        |> apply_authentication
        |> send_query_request
        |> filter_data
      end

      # Privates
      defp crc_signature_checker(%ApiRequest{state: :unmanaged} = req) do
        # Api.App.CrcSignature.verify(req)
        # req
      end

      defp filter_data(%ApiRequest{state: :managed, filter: filter} = req)
           when not is_nil(filter),
           do: filter.(req)

      defp filter_data(%ApiRequest{} = req), do: req

      defp send_query_request(%ApiRequest{state: :unmanaged, projection: projection, query: query, params: params} = req) do
        with {:ok, module} <- Seven.Projections.get_projection(projection),
             {:ok, data} <- module.query(query, params) do
          %ApiRequest{req | state: :managed, response: data}
        else
          {:error, :projection_not_found} ->
            %ApiRequest{req | state: :projection_not_found}

          {:error, reason} ->
            %ApiRequest{req | state: {:routed_but_invalid, reason}}
        end
      end

      defp send_query_request(%ApiRequest{} = req), do: req

      unquote do
        {_, _, p} = post

        if p[:authentication] |> is_not_nil do
          quote do
            defp apply_authentication(%ApiRequest{state: :unmanaged, projection: unquote(p[:projection])} = req),
              do: unquote(p[:authentication]).(req)
          end
        end
      end

      defp apply_authentication(%ApiRequest{} = req), do: req
    end
  end
end
