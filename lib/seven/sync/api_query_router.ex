defmodule Seven.Sync.ApiQueryRouter do
  @moduledoc false

  defp is_not_nil(arg), do: not is_nil(arg)

  defmacro __using__(post: post) do
    quote location: :keep do
      alias Seven.Sync.ApiRequest

      @doc false
      @spec run(map) :: any
      def run(params) do
        %ApiRequest{
          state: :unmanaged,
          params: params,
          projection: unquote(post).projection,
          query: unquote(post).query
        }
        |> internal_pre_query
        |> send_query_request
        |> internal_post_query
      end

      #
      # Privates
      #
      unquote do
        {_, _, p} = post

        if p[:pre_query] |> is_not_nil do
          quote do
            defp internal_pre_query(%ApiRequest{state: :unmanaged} = req) do
              case unquote(p[:pre_query]).(req) do
                :ok -> req
                {:ok, req} -> req
                err -> %ApiRequest{req | state: err}
              end
            end
          end
        end
      end

      defp internal_pre_query(%ApiRequest{} = req), do: req

      unquote do
        {_, _, p} = post

        if p[:post_query] |> is_not_nil do
          quote do
            defp internal_post_query(%ApiRequest{state: :managed} = req),
              do: unquote(p[:post_query]).(req, req.response)
          end
        else
          quote do
            defp internal_post_query(%ApiRequest{state: :managed} = req), do: req.response
          end
        end
      end

      defp internal_post_query(%ApiRequest{} = req), do: req.state

      defp send_query_request(%ApiRequest{state: :unmanaged, projection: projection, query: query, params: params} = req) do
        with {:ok, module} <- Seven.Projections.get_projection(projection),
             data <- module.query(query, params) do
          %ApiRequest{req | state: :managed, response: data}
        else
          {:error, :projection_not_found} ->
            %ApiRequest{req | state: :projection_not_found}

          {:error, reason} ->
            %ApiRequest{req | state: {:routed_but_invalid, reason}}
        end
      end

      defp send_query_request(%ApiRequest{} = req), do: req
    end
  end
end
