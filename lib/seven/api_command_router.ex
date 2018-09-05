defmodule Seven.ApiCommandRouter do
  defp is_not_nil(arg), do: not is_nil(arg)

  defmacro __using__(post: post) do
    quote location: :keep do
      alias Seven.ApiRequest

      @doc false
      def run(conn) do
        %ApiRequest{
          request_id: Seven.Data.Persistence.new_id(),
          command: unquote(post).command,
          req_headers: conn.req_headers,
          params: conn.params,
          wait_for_events: unquote(post)[:wait_for_events]
        }
        |> apply_crc_signature
        |> sync_validation
        |> apply_authentication
        |> subscribe_to_event_store
        |> send_command_request
        |> wait_events
        |> unsubscribe_to_event_store
        |> prepare_response
      end

      # Privates

      unquote do
        {_, _, p} = post

        if p[:crc_signature] |> is_not_nil do
          quote do
            defp apply_crc_signature(%ApiRequest{state: :unmanaged, command: unquote(p[:command])} = req), do: unquote(p[:crc_signature]).(req)
          end
        end
      end

      defp apply_crc_signature(%ApiRequest{} = req), do: req

      defp wait_events(%ApiRequest{state: :managed, wait_for_events: []} = req), do: req

      defp wait_events(%ApiRequest{state: :managed, wait_for_events: events} = req) do
        incoming_events = wait_for_one_of_events(req.request_id, events, [])
        %ApiRequest{req | events: incoming_events}
      end

      defp wait_events(%ApiRequest{} = req), do: req

      defp subscribe_to_event_store(%ApiRequest{state: :unmanaged, wait_for_events: []} = req),
        do: req

      defp subscribe_to_event_store(%ApiRequest{state: :unmanaged, wait_for_events: wait_for_events} = req) do
        wait_for_events |> Enum.each(&Seven.EventStore.subscribe(&1, self()))
        req
      end

      defp subscribe_to_event_store(%ApiRequest{} = req), do: req

      unquote do
        {_, _, p} = post

        if p[:sync_validation] |> is_not_nil do
          quote do
            defp sync_validation( %ApiRequest{state: :unmanaged, command: unquote(p[:command])} = req) do
              %ApiRequest{req | state: unquote(p[:sync_validation]).(req)}
            end
          end
        end
      end

      defp sync_validation(%ApiRequest{} = req), do: req

      unquote do
        {_, _, p} = post

        if p[:authentication] |> is_not_nil do
          quote do
            defp apply_authentication(%ApiRequest{state: :unmanaged, command: unquote(p[:command])} = req), do: unquote(p[:authentication]).(req)
          end
        end
      end

      defp apply_authentication(%ApiRequest{} = req), do: req

      defp unsubscribe_to_event_store(%ApiRequest{state: :managed, wait_for_events: []} = req),
        do: req

      defp unsubscribe_to_event_store( %ApiRequest{state: :managed, wait_for_events: wait_for_events} = req) do
        wait_for_events |> Enum.each(&Seven.EventStore.unsubscribe(&1, self()))
        req
      end

      defp unsubscribe_to_event_store(%ApiRequest{} = req), do: req

      defp send_command_request(%ApiRequest{state: :unmanaged} = req) do
        res =
          %Seven.CommandRequest{
            id: req.request_id,
            command: req.command,
            sender: __MODULE__,
            params: AtomicMap.convert(req.params, safe: false)
          }
          |> Seven.Log.command_request_sent()
          |> Seven.CommandBus.send_command_request()

        %ApiRequest{req | state: res}
      end

      defp send_command_request(%ApiRequest{} = req), do: req

      unquote do
        {_, _, p} = post

        if p[:prepare_response] |> is_not_nil do
          we = p[:wait_for_events] || []

          case length(we) do
            0 ->
              quote do
                defp prepare_response(%ApiRequest{state: :managed, command: unquote(p[:command]), events: []} = req), do: req
              end

            _ ->
              quote do
                defp prepare_response(%ApiRequest{state: :managed, command: unquote(p[:command]), events: [e1]} = req), do: unquote(p[:prepare_response]).(req, e1)
              end
          end
        end
      end

      # no events to wait for
      defp prepare_response(%ApiRequest{state: :managed, wait_for_events: [], events: []} = req), do: req
      defp prepare_response(%ApiRequest{state: :managed, events: []} = req), do: %ApiRequest{req | state: :timeout}
      defp prepare_response(%ApiRequest{} = req), do: req

      @command_timeout 5000

      defp wait_for_one_of_events(_request_id, [], incoming_events), do: incoming_events
      defp wait_for_one_of_events(request_id, events, incoming_events) do
        receive do
          %Seven.Event{request_id: ^request_id} = e ->
            if e.type not in events do
              wait_for_one_of_events(request_id, events, incoming_events)
            else
              incoming_events ++ [e]
            end

          _ ->
            wait_for_one_of_events(request_id, events, incoming_events)
        after
          @command_timeout -> []
        end
      end
    end
  end
end
