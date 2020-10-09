defmodule Seven.Utils.Snapshot do
  alias Seven.Data.Persistence

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

  def get_snap(correlation_id), do: Persistence.get_snapshot(correlation_id)

  def get_state(binary_state), do: :erlang.binary_to_term(binary_state)

  def snap_if_needed(%__MODULE__{} = snapshot, state) do
    need = snapshot.events_to_snapshot >= @events_for_snapshot
    snap_now(need, snapshot, state)
  end

  defp snap_now(false, snapshot, _state), do: snapshot

  defp snap_now(_, snapshot, state) do
    snapshot = Map.put(snapshot, :events_to_snapshot, 0)

    snap =
      new(snapshot)
      |> Map.put(:created_at, DateTime.utc_now() |> DateTime.to_iso8601())
      |> Map.put(:state, state |> :erlang.term_to_binary())

    Persistence.upsert_snapshot(snap.correlation_id, snap)

    snapshot
  end
end
