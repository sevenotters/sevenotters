defmodule Seven.Utils.AggregateSnapshotState do

  alias Seven.Data.Persistence

  @events_for_snapshot 100

  defstruct [
    correlation_id: nil,
    last_event_id: nil,
    events_to_snapshot: 0
  ]

  def new(correlation_id) do
    %__MODULE__{correlation_id: correlation_id}
  end

  def update_last_event(%__MODULE__{} = snapshot, []), do: snapshot
  def update_last_event(%__MODULE__{} = snapshot, events) do
    Map.put(snapshot, :last_event_id, List.last(events).id)
  end

  def increment_events_to_snapshot(%__MODULE__{} = snapshot, num_events) do
    Map.put(snapshot, :events_to_snapshot, snapshot.events_to_snapshot + num_events)
  end

  def snap_if_needed(%__MODULE__{} = snapshot, state) do
    need = snapshot.events_to_snapshot >= @events_for_snapshot
    snap_now(need, snapshot, state)
  end

  defp snap_now(false, snapshot, _state), do: snapshot
  defp snap_now(_, snapshot, state) do
    snap =
      %Seven.Utils.Snapshot{
        correlation_id: snapshot.correlation_id,
        created_at: NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601(),
        last_event_id: snapshot.last_event_id,
        state: state |> :erlang.term_to_binary()
      }

    Persistence.upsert_snapshot(snapshot.correlation_id, snap)
    Map.put(snapshot, :events_to_snapshot, 0)
  end
end
