defmodule Seven.Data.InMemory do
  @moduledoc false
  use GenServer
  require Logger

  @behaviour SevenottersPersistence.Storage

  @id_regex ~r/^[A-Fa-f0-9\-]{24}$/

  def start_link(opts \\ []) do
    Logger.info("Persistence is InMemory")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}}
  end

  @spec insert(String.t(), Map.t()) :: any
  def insert(collection, value) do
    GenServer.cast(__MODULE__, {:insert, [collection, value]})
  end

  @spec new_id :: any
  def new_id, do: UUID.uuid4(:hex)

  @spec printable_id(any) :: String.t()
  def printable_id(id) when is_bitstring(id), do: id

  @spec object_id(String.t()) :: any
  def object_id(id), do: id

  @spec is_valid_id?(any) :: Boolean.t()
  def is_valid_id?(id) when is_bitstring(id), do: Regex.match?(@id_regex, id)

  @spec max_in_collection(String.t(), atom) :: Int.t()
  def max_in_collection(collection, field) do
    GenServer.call(__MODULE__, {:max_in_collection, collection, field})
  end

  @spec content_of(String.t(), Map.t(), Map.t()) :: List.t()
  def content_of(collection, filter, sort) do
    GenServer.call(__MODULE__, {:content_of, collection, filter, sort})
  end

  @spec drop_collections(List.t()) :: any
  def drop_collections(collections) do
    GenServer.cast(__MODULE__, {:drop_collections, collections})
  end

  @spec sort_expression() :: any
  def sort_expression(), do: :counter

  @spec type_expression([String.t()]) :: any
  def type_expression(types), do: %{types: types}

  #
  # Callbacks
  #
  def handle_call({:max_in_collection, collection, field}, _from, state) do
    items =
      state
      |> Map.get(collection, [])
      |> Enum.max_by(&Map.fetch(&1, field), fn -> 0 end)
    {:reply, items, state}
  end

  def handle_call({:content_of, collection, %{types: types}, sort}, _from, state) do
    items =
      state
      |> Map.get(collection, [])
      |> Enum.filter(fn i -> i.type in types end)
      |> Enum.sort_by(&Map.fetch(&1, sort))
    {:reply, items, state}
  end

  def handle_call({:content_of, collection, filter, sort}, _from, state) do
    items =
      state
      |> Map.get(collection, [])
      |> Enum.filter(fn i -> match?(^filter, i) end)
      |> Enum.sort_by(&Map.fetch(&1, sort))
    {:reply, items, state}
  end

  def handle_cast({:drop_collections, collections}, state) do
    state = collections |> Enum.reduce(state, fn c, state -> state |> Map.put(c, []) end)
    {:noreply, state}
  end

  def handle_cast({:insert, [collection, value]}, state) do
    items = state |> Map.get(collection, [])
    state = state |> Map.put(collection, items ++ [value])
    {:noreply, state}
  end
end
