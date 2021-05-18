defmodule Seven.Data.InMemory do
  @moduledoc false
  use GenServer
  alias Seven.Log

  @behaviour Seven.Data.PersistenceBehaviour

  @id_regex ~r/^[A-Fa-f0-9\-]{24}$/

  defstruct events: [], processes: []

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

  @spec upsert_process(bitstring, map) :: any
  def upsert_process(process_id, value) do
    GenServer.cast(__MODULE__, {:upsert_process, [process_id, value]})
  end

  @spec get_process(bitstring) :: map | nil
  def get_process(process_id) do
    GenServer.call(__MODULE__, {:get_process, process_id})
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

  @spec events_by_correlation_id(bitstring, integer) :: [map]
  def events_by_correlation_id(correlation_id, after_counter) do
    GenServer.call(__MODULE__, {:events_by_correlation_id, correlation_id, after_counter})
  end

  @spec event_by_id(bitstring) :: map
  def event_by_id(id) do
    GenServer.call(__MODULE__, {:event_by_id, id})
  end

  @spec events_by_types([bitstring], integer) :: [map]
  def events_by_types(types, after_counter) do
    GenServer.call(__MODULE__, {:events_by_types, types, after_counter})
  end

  @spec events() :: [map]
  def events(), do: GenServer.call(__MODULE__, :events)

  @spec processes() :: [map]
  def processes(), do: GenServer.call(__MODULE__, :processes)

  @spec drop_events() :: any
  def drop_events(), do: GenServer.call(__MODULE__, :drop_events)

  @spec drop_processes() :: any
  def drop_processes(), do: GenServer.call(__MODULE__, :drop_processes)

  @callback processes_id_by_status(bitstring) :: [map]
  def processes_id_by_status(status) do
    GenServer.call(__MODULE__, {:processes_id_by_status, status})
  end

  @callback events_reduce(any, any, fun()) :: any
  def events_reduce(stream, acc, fun) do
    Enum.reduce(stream, acc, fun)
  end

  #
  # Callbacks
  #
  def handle_call({:processes_id_by_status, status}, _from, %{processes: processes} = state) do
    process =
      processes
      |> Enum.filter(fn p -> p.status == status end)
      |> Enum.map(fn p -> p.process_id end)

    {:reply, process, state}
  end

  def handle_call({:get_process, process_id}, _from, %{processes: processes} = state) do
    process = processes |> Enum.find(fn p -> p.process_id == process_id end)
    {:reply, process, state}
  end

  def handle_call(:max_counter_in_events, _from, %{events: events} = state) do
    items = events |> Enum.max_by(&Map.fetch(&1, :counter), fn -> 0 end)
    {:reply, items, state}
  end

  def handle_call({:events_by_types, types, after_counter}, _from, %{events: events} = state) do
    events =
      events
      |> Enum.filter(fn e -> e.type in types end)
      |> filter_after_counter(after_counter)
      |> Enum.sort_by(&Map.fetch(&1, :counter))

    {:reply, events, state}
  end

  def handle_call({:events_by_correlation_id, correlation_id, after_counter}, _from, %{events: events} = state) do
    events =
      events
      |> Enum.filter(fn e -> e.correlation_id == correlation_id end)
      |> filter_after_counter(after_counter)
      |> Enum.sort_by(&Map.fetch(&1, :counter))

    {:reply, events, state}
  end

  def handle_call({:event_by_id, id}, _from, %{events: events} = state) do
    {:reply, Enum.find(events, fn e -> e.id == id end), state}
  end

  def handle_call(:events, _from, %{events: events} = state), do: {:reply, events, state}

  def handle_call(:processes, _from, %{processes: processes} = state), do: {:reply, processes, state}

  def handle_call(:drop_events, _from, state), do: {:reply, nil, %{state | events: []}}

  def handle_call(:drop_processes, _from, state), do: {:reply, nil, %{state | processes: []}}

  defp filter_after_counter(events, -1), do: events

  defp filter_after_counter(events, counter) do
    Enum.filter(events, fn e -> e.counter > counter end)
  end

  def handle_cast({:insert_event, value}, state) do
    {:noreply, %{state | events: state.events ++ [value]}}
  end

  def handle_cast({:upsert_process, [process_id, value]}, %{processes: processes} = state) do
    processes =
      case Enum.find_index(processes, fn p -> p.process_id == process_id end) do
        nil -> processes ++ [value]
        index -> put_in(processes, [Access.at(index)], value)
      end

    {:noreply, %{state | processes: processes}}
  end
end
