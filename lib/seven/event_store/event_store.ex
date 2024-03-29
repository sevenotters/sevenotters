defmodule Seven.EventStore.EventStore do
  use GenServer

  @moduledoc false

  alias Seven.Data.Persistence
  alias Seven.EventStore.State

  # API
  @spec start_link(List.t()) :: {:ok, pid}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  @spec subscribe(String.t(), pid) :: any
  def subscribe(event_type, subscriber_pid)
      when is_pid(subscriber_pid) and is_bitstring(event_type) do
    GenServer.cast(__MODULE__, {:subscribe, event_type, subscriber_pid})
  end

  @spec unsubscribe(String.t(), pid) :: any
  def unsubscribe(event_type, subscriber_pid)
      when is_pid(subscriber_pid) and is_bitstring(event_type) do
    GenServer.cast(__MODULE__, {:unsubscribe, event_type, subscriber_pid})
  end

  @spec fire(Map.t()) :: any
  def fire(event), do: GenServer.call(__MODULE__, {:fire, event})

  @spec state() :: any
  def state(), do: GenServer.call(__MODULE__, :state)

  @spec events_by_correlation_id(bitstring, integer) :: [map]
  def events_by_correlation_id(correlation_id, after_counter \\ -1),
    do: Persistence.events_by_correlation_id(correlation_id, after_counter)

  @spec event_by_id(bitstring) :: map
  def event_by_id(id),
    do: Persistence.event_by_id(id)

  @spec events_by_types([bitstring], integer) :: any
  def events_by_types(types, after_counter \\ -1),
    do: Persistence.events_by_types(types, after_counter)

  def events_reduce(stream, acc, fun) do
    Persistence.events_reduce(stream, acc, &fun.(to_event(&1), &2))
  end

  # Callbacks
  def init(:ok) do
    Seven.Log.info("#{__MODULE__} started.")
    Persistence.initialize()

    next_counter = Persistence.max_counter_in_events() + State.counter_step()
    Seven.Log.debug("Next event counter: #{next_counter}")

    {:ok, State.init(next_counter)}
  end

  def handle_call(:state, _from, state),
    do: {:reply, %{event_store: state, events: Persistence.events()}, state}

  def handle_call({:fire, event}, _from, state) do
    event = Map.put(event, :counter, State.next_counter(state))
    persist(event)

    Seven.Log.event_fired(event)
    fire(event, State.pids_by_event(state, event.type))

    {:reply, event, State.increment_counter(state)}
  end

  def handle_cast({:subscribe, event_type, pid}, state) do
    new_state = State.subscribe_pid_to_event(state, pid, event_type)
    {:noreply, new_state}
  end

  def handle_cast({:unsubscribe, event_type, pid}, state) do
    new_state = State.unsubscribe_pid_to_event(state, pid, event_type)
    {:noreply, new_state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    Seven.Log.debug("#{__MODULE__} subscriber :DOWN - ref: #{inspect(ref)} - pid: #{inspect(pid)} - reason: #{inspect(reason)}")

    {:noreply, State.pid_is_down(state, pid)}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Privates
  defp fire(event, pids), do: pids |> broadcast(event)

  defp to_event(event) do
    struct(Seven.Otters.Event, AtomicMap.convert(event, safe: false))
  end

  defp broadcast([], event), do: event

  defp broadcast([pid | tail], event) do
    send(pid, event)
    broadcast(tail, event)
  end

  defp persist(event), do: Persistence.insert_event(event)
end
