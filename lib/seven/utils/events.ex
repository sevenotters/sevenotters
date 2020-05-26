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
end
