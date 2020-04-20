defmodule Seven.EventStore.EventStore do
  use GenServer

  @moduledoc false

  alias Seven.Data.Persistence
  alias Seven.EventStore.State

  @events_collection "events"
  @counter_field :counter

  # API
  @spec start_link(List.t()) :: {:ok, pid}
  def start_link(opts \\ []) do
    next_counter = Persistence.max_in_collection(@events_collection, @counter_field) + State.counter_step()
    Seven.Log.debug("Next event counter: #{next_counter}")

    GenServer.start_link(__MODULE__, {:ok, next_counter}, opts ++ [name: __MODULE__])
  end

  @spec subscribe(String.t(), pid) :: any
  def subscribe(event_type, subscriber_pid)
      when is_pid(subscriber_pid) and is_bitstring(event_type) do
    GenServer.call(__MODULE__, {:subscribe, event_type, subscriber_pid})
  end

  @spec unsubscribe(String.t(), pid) :: any
  def unsubscribe(event_type, subscriber_pid)
      when is_pid(subscriber_pid) and is_bitstring(event_type) do
    GenServer.call(__MODULE__, {:unsubscribe, event_type, subscriber_pid})
  end

  @spec fire(Map.t()) :: any
  def fire(event), do: GenServer.cast(__MODULE__, {:fire, event})

  @spec state() :: any
  def state(), do: GenServer.call(__MODULE__, :state)

  @spec events_by(Map.t()) :: List.t()
  def events_by(filter) when is_map(filter), do: GenServer.call(__MODULE__, {:events_by, filter})

  @spec events_by_types([String.t()]) :: List.t()
  def events_by_types(types), do: GenServer.call(__MODULE__, {:events_by_types, types})

  # Callbacks
  def init({:ok, next_counter}) do
    Seven.Log.info("#{__MODULE__} started.")
    {:ok, State.init(next_counter)}
  end

  def handle_call(:state, _from, state),
    do: {:reply, %{event_store: state, events: Persistence.content_of(@events_collection)}, state}

  def handle_call({:subscribe, event_type, pid}, _from, state) do
    new_state = State.subscribe_pid_to_event(state, pid, event_type)
    {:reply, pid, new_state}
  end

  def handle_call({:unsubscribe, event_type, pid}, _from, state) do
    new_state = State.unsubscribe_pid_to_event(state, pid, event_type)
    {:reply, pid, new_state}
  end

  def handle_call({:events_by, filter}, _from, state) do
    sort_expression = Persistence.sort_expression()
    events = Persistence.content_of(@events_collection, filter, sort_expression) |> to_events
    {:reply, events, state}
  end

  def handle_call({:events_by_types, types}, _from, state) do
    type_expression = Persistence.type_expression(types)
    sort_expression = Persistence.sort_expression()
    events =
      Persistence.content_of(@events_collection, type_expression, sort_expression)
      |> to_events

    {:reply, events, state}
  end

  def handle_cast({:fire, event}, state) do
    event = Map.put(event, @counter_field, State.next_counter(state))
    persist(event)

    Seven.Log.event_fired(event)
    fire(event, State.pids_by_event(state, event.type))

    {:noreply, State.increment_counter(state)}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    Seven.Log.debug("#{__MODULE__} subscriber :DOWN - ref: #{inspect(ref)} - pid: #{inspect(pid)} - reason: #{inspect(reason)}")

    {:noreply, State.pid_is_down(state, pid)}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Privates
  defp fire(event, pids), do: pids |> broadcast(event)

  defp to_events(events) when is_list(events) do
    events
    |> Enum.map(fn e -> struct(Seven.Otters.Event, AtomicMap.convert(e, safe: false)) end)
  end

  defp broadcast([], event), do: event

  defp broadcast([pid | tail], event) do
    send(pid, event)
    broadcast(tail, event)
  end

  defp persist(event), do: Persistence.insert(@events_collection, event)
end
