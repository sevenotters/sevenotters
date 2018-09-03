defmodule Seven.EventStoreState do
  @moduledoc false

  @type string_to_pids :: Map.t()
  @type pid_to_strings :: Map.t()
  @type pid_to_references :: Map.t()

  @opaque t :: %__MODULE__{
            event_to_pids: string_to_pids,
            pid_to_events: pid_to_strings,
            pid_to_monitor: pid_to_references,
            next_counter: Integer.t()
          }

  defstruct event_to_pids: %{},
            pid_to_events: %{},
            pid_to_monitor: %{},
            next_counter: 0

  # API
  def counter_step, do: 10

  @spec init(Integer.t()) :: Map.t()
  def init(next_counter), do: %__MODULE__{next_counter: next_counter}

  @spec increment_counter(Map.t()) :: Map.t()
  def increment_counter(state), do: %{state | next_counter: state.next_counter + counter_step()}

  @spec next_counter(Map.t()) :: Integer.t()
  def next_counter(state), do: state.next_counter

  @spec pids_by_event(Map.t(), String.t()) :: List.t()
  def pids_by_event(state, event_type),
    do: get_in(state.event_to_pids, [event_type]) |> get_collection()

  @spec pid_is_down(Map.t(), pid) :: Map.t()
  def pid_is_down(state, pid) do
    event_to_pids =
      state.event_to_pids
      |> Enum.reduce(%{}, fn {e, pids}, acc -> put_in(acc, [e], pids -- [pid]) end)

    demonitor(state.pid_to_monitor[pid])

    pid_to_monitor = state.pid_to_monitor |> Map.delete(pid)
    pid_to_events = state.pid_to_events |> Map.delete(pid)

    %{
      state
      | event_to_pids: event_to_pids,
        pid_to_events: pid_to_events,
        pid_to_monitor: pid_to_monitor
    }
  end

  @spec subscribe_pid_to_event(Map.t(), pid, String.t()) :: Map.t()
  def subscribe_pid_to_event(state, pid, event_type) do
    current_collection = get_in(state.event_to_pids, [event_type]) |> get_collection()
    event_to_pids = put_in(state.event_to_pids, [event_type], current_collection ++ [pid])

    current_pid_to_events = get_in(state.pid_to_events, [pid]) |> get_collection()
    pid_to_events = put_in(state.pid_to_events, [pid], current_pid_to_events ++ [event_type])

    monitor_ref = monitor(pid)
    pid_to_monitor = state.pid_to_monitor |> Map.put(pid, monitor_ref)

    %{
      state
      | event_to_pids: event_to_pids,
        pid_to_events: pid_to_events,
        pid_to_monitor: pid_to_monitor
    }
  end

  @spec unsubscribe_pid_to_event(Map.t(), pid, String.t()) :: Map.t()
  def unsubscribe_pid_to_event(state, pid, event_type) do
    current_event_to_pids = get_in(state.event_to_pids, [event_type]) |> get_collection()
    event_to_pids = put_in(state.event_to_pids, [event_type], current_event_to_pids -- [pid])

    current_pid_to_events = get_in(state.pid_to_events, [pid]) |> get_collection()
    pid_to_events = put_in(state.pid_to_events, [pid], current_pid_to_events -- [event_type])

    # demonitor this subscriptor
    {pid_to_events, pid_to_monitor} =
      case length(pid_to_events[pid]) do
        0 ->
          demonitor(state.pid_to_monitor[pid])
          {Map.delete(pid_to_events, pid), Map.delete(state.pid_to_monitor, pid)}

        _ ->
          {pid_to_events, state.pid_to_monitor}
      end

    %{
      state
      | event_to_pids: event_to_pids,
        pid_to_events: pid_to_events,
        pid_to_monitor: pid_to_monitor
    }
  end

  @spec monitor(pid) :: any
  defp monitor(pid), do: Process.monitor(pid)

  @spec demonitor(any) :: any
  defp demonitor(nil), do: nil
  defp demonitor(ref), do: Process.demonitor(ref)

  # Privates
  defp get_collection(nil), do: []
  defp get_collection(c), do: c
end
