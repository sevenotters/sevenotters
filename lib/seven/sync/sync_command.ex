defmodule Seven.Sync.SyncCommand do
  @moduledoc false

  alias Seven.Sync.SyncCommandRequest
  alias Seven.EventStore.EventStore

  @spec execute(Seven.Sync.SyncCommandRequest.t()) ::
          {:ok, Seven.Otters.Event.t()} | {:error, any}
  def execute(command_request) do
    command_request
    |> Map.merge(%{request_id: Seven.Data.Persistence.new_id()})
    |> subscribe_to_event_store
    |> send_command_request
    |> wait_events
    |> unsubscribe_to_event_store
    |> prepare_response
  end

  defp wait_events(%SyncCommandRequest{state: :managed, wait_for_events: []} = req), do: req

  defp wait_events(%SyncCommandRequest{state: :managed, wait_for_events: events} = req) do
    incoming_events = wait_for_one_of_events(req.request_id, events, [])
    %SyncCommandRequest{req | events: incoming_events}
  end

  defp wait_events(%SyncCommandRequest{} = req), do: req

  defp subscribe_to_event_store(%SyncCommandRequest{state: :unmanaged, wait_for_events: []} = req),
    do: req

  defp subscribe_to_event_store(%SyncCommandRequest{state: :unmanaged, wait_for_events: wait_for_events} = req) do
    wait_for_events |> Enum.each(&EventStore.subscribe(&1, self()))
    req
  end

  defp subscribe_to_event_store(%SyncCommandRequest{} = req), do: req

  defp unsubscribe_to_event_store(%SyncCommandRequest{state: :managed, wait_for_events: []} = req),
    do: req

  defp unsubscribe_to_event_store(%SyncCommandRequest{state: :managed, wait_for_events: wait_for_events} = req) do
    wait_for_events |> Enum.each(&EventStore.unsubscribe(&1, self()))
    req
  end

  defp unsubscribe_to_event_store(%SyncCommandRequest{} = req), do: req

  defp send_command_request(%SyncCommandRequest{state: :unmanaged} = req) do
    res =
      %Seven.CommandRequest{
        id: req.request_id,
        command: req.command,
        sender: __MODULE__,
        params: AtomicMap.convert(req.params, safe: false)
      }
      |> Seven.Log.command_request_sent()
      |> Seven.CommandBus.send_command_request()

    %SyncCommandRequest{req | state: res}
  end

  defp send_command_request(%SyncCommandRequest{} = req), do: req

  defp prepare_response(%SyncCommandRequest{state: :unmanaged} = req), do: {:error, req.response}

  defp prepare_response(%SyncCommandRequest{state: :managed, events: []}), do: {:error, :timeout}

  defp prepare_response(%SyncCommandRequest{state: state, events: []}), do: {:error, state}

  defp prepare_response(%SyncCommandRequest{events: [e1]}), do: {:ok, e1}

  @command_timeout 5000

  defp wait_for_one_of_events(_request_id, [], incoming_events), do: incoming_events

  defp wait_for_one_of_events(request_id, events, incoming_events) do
    receive do
      %Seven.Otters.Event{request_id: ^request_id} = e ->
        if e.type in events do
          incoming_events ++ [e]
        else
          wait_for_one_of_events(request_id, events, incoming_events)
        end

      _ ->
        wait_for_one_of_events(request_id, events, incoming_events)
    after
      @command_timeout -> []
    end
  end
end
