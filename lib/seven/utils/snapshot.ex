defmodule Seven.Utils.Snapshot do
  @events_for_snapshot 100

  defstruct correlation_id: nil,
            last_event_id: nil,
            events_to_snapshot: 0,
            created_at: nil,
            state: nil

  def new(%__MODULE__{} = snapshot) do
    %__MODULE__{
      correlation_id: snapshot.correlation_id,
      last_event_id: snapshot.last_event_id,
      events_to_snapshot: snapshot.events_to_snapshot
    }
  end

  def new(correlation_id) do
    %__MODULE__{correlation_id: correlation_id}
  end

  def add_events(%__MODULE__{} = snapshot, []), do: snapshot

  def add_events(%__MODULE__{} = snapshot, events) do
    %{snapshot | events_to_snapshot: snapshot.events_to_snapshot + length(events), last_event_id: List.last(events).id}
  end

  def get_snap(correlation_id, read_fun), do: read_fun.(correlation_id)

  def get_state(binary_state), do: :erlang.binary_to_term(binary_state)

  def snap_if_needed(%__MODULE__{} = snapshot, state, write_func) do
    need = snapshot.events_to_snapshot >= @events_for_snapshot
    snap_now(need, snapshot, write_func, state)
  end

  defp snap_now(false, snapshot, _write_func, _state), do: snapshot

  defp snap_now(_, snapshot, write_func, state) do
    snapshot = Map.put(snapshot, :events_to_snapshot, 0)

    snap =
      new(snapshot)
      |> Map.put(:created_at, DateTime.utc_now() |> DateTime.to_iso8601())
      |> Map.put(:state, state |> :erlang.term_to_binary())

    write_func.(snap.correlation_id, snap)

    snapshot
  end
end
