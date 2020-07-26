defmodule Seven.Data.InMemory do
  @moduledoc false
  use GenServer
  alias Seven.Log

  @behaviour SevenottersPersistence.Storage

  @id_regex ~r/^[A-Fa-f0-9\-]{24}$/

  defstruct events: [], snapshots: []

  def start_link(opts \\ []) do
    Log.info("Persistence is InMemory")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts), do: {:ok, %__MODULE__{}}

  @spec initialize() :: any
  def initialize(), do: nil

  @spec insert_event(map) :: any
  def insert_event(value) do
    GenServer.cast(__MODULE__, {:insert_event, value})
  end

  @spec upsert_snapshot(bitstring, map) :: any
  def upsert_snapshot(correlation_id, value) do
    GenServer.cast(__MODULE__, {:upsert_snapshot, [correlation_id, value]})
  end

  @spec new_id :: any
  def new_id, do: UUID.uuid4(:hex)

  @spec new_printable_id :: bitstring
  def new_printable_id, do: new_id()

  @spec printable_id(any) :: bitstring
  def printable_id(id) when is_bitstring(id), do: id

  @spec object_id(bitstring) :: any
  def object_id(id), do: id

  @spec is_valid_id?(any) :: boolean
  def is_valid_id?(id) when is_bitstring(id), do: Regex.match?(@id_regex, id)

  @spec max_counter_in_events() :: integer
  def max_counter_in_events(), do: GenServer.call(__MODULE__, :max_counter_in_events)

  @spec events_by_correlation_id(bitstring) :: [map]
  def events_by_correlation_id(correlation_id) do
    GenServer.call(__MODULE__, {:events_by_correlation_id, correlation_id})
  end

  @spec events_by_types([bitstring]) :: [map]
  def events_by_types(types) do
    GenServer.call(__MODULE__, {:events_by_types, types})
  end

  @spec events() :: [map]
  def events(), do: GenServer.call(__MODULE__, :events)

  @spec snapshots() :: [map]
  def snapshots(), do: GenServer.call(__MODULE__, :snapshots)

  @spec drop_events() :: any
  def drop_events(), do: GenServer.call(__MODULE__, :drop_events)

  @spec drop_snapshots() :: any
  def drop_snapshots(), do: GenServer.call(__MODULE__, :drop_snapshots)

  #
  # Callbacks
  #
  def handle_call(:max_counter_in_events, _from, %{events: events} = state) do
    items = events |> Enum.max_by(&Map.fetch(&1, :counter), fn -> 0 end)
    {:reply, items, state}
  end

  def handle_call({:events_by_types, types}, _from, %{events: events} = state) do
    events =
      events
      |> Enum.filter(fn e -> e.type in types end)
      |> Enum.sort_by(&Map.fetch(&1, :counter))

    {:reply, events, state}
  end

  def handle_call({:events_by_correlation_id, correlation_id}, _from, %{events: events} = state) do
    _filter = %{correlation_id: correlation_id}
    events =
      events
      |> Enum.filter(fn e -> match?(_filter, e) end)
      |> Enum.sort_by(&Map.fetch(&1, :counter))

    {:reply, events, state}
  end

  def handle_call(:events, _from, %{events: events} = state), do: {:reply, events, state}

  def handle_call(:snapshots, _from, %{snapshots: snapshots} = state), do: {:reply, snapshots, state}

  def handle_call(:drop_events, _from, state), do: {:reply, nil, %{state | events: []}}

  def handle_call(:drop_snapshots, _from, state), do: {:reply, nil, %{state | snapshots: []}}

  def handle_cast({:insert_event, value}, state) do
    {:noreply, %{state | events: state.events ++ [value]}}
  end

  def handle_cast({:upsert_snapshot, [correlation_id, value]}, %{snapshots: snapshots} = state) do
    _filter = %{correlation_id: correlation_id}

    snapshots =
      case Enum.find_index(snapshots, fn s -> match?(_filter, s) end) do
        nil   -> snapshots ++ [value]
        index -> put_in(snapshots, [Access.at(index)], value)
      end

    {:noreply, %{state | snapshots: snapshots}}
  end
end
