defmodule Seven.Utils.Events do
  @event_listening_timeout 5000

  @spec wait_for_event(bitstring, bitstring) :: Seven.Otters.Event | nil
  def wait_for_event(request_id, event_type) do
    receive do
      %Seven.Otters.Event{request_id: ^request_id, type: ^event_type} = e -> e
      _ -> wait_for_event(request_id, event_type)
    after
      @event_listening_timeout -> nil
    end
  end

  @spec create_event(bitstring, map) :: map
  def create_event(type, payload) do
    Seven.Otters.Event.create(type, payload, __MODULE__)
  end

  @spec set_request_id([Seven.Otters.Event], bitstring) :: [Seven.Otters.Event]
  def set_request_id(events, request_id),
    do: Enum.map(events, &Map.put(&1, :request_id, request_id))

  @spec trigger([Seven.Otters.Event]) :: :ok
  def trigger([]), do: :ok

  def trigger([event | events]) do
    Seven.EventStore.EventStore.fire(event)
    trigger(events)
  end

  @spec set_correlation_id([Seven.Otters.Event] | Seven.Otters.Event, bitstring) :: [Seven.Otters.Event]
  def set_correlation_id(events, correlation_id) when is_list(events) do
    Enum.map(events, fn e -> set_correlation_id(e, correlation_id) end)
  end

  def set_correlation_id(event, correlation_id), do: Map.put(event, :correlation_id, correlation_id)

  def set_process_id(events, nil), do: events

  def set_process_id(events, process_id) when is_list(events) do
    Enum.map(events, fn e -> set_process_id(e, process_id) end)
  end

  def set_process_id(event, process_id), do: Map.put(event, :process_id, process_id)
end
