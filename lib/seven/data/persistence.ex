defmodule Seven.Data.Persistence do
  @moduledoc false

  alias Seven.Log

  @spec current() :: atom
  def current do
    Log.info("Using persistence: #{persistence()}")
    persistence()
  end

  @spec initialize() :: any
  def initialize(), do: persistence().initialize()

  @spec insert_event(map) :: any
  def insert_event(%{__struct__: _} = value),
    do: persistence().insert_event(value |> Map.from_struct())

  @spec upsert_snapshot(map, map) :: any
  def upsert_snapshot(correlation_id, %{__struct__: _} = value),
    do: persistence().upsert_snapshot(correlation_id, value |> Map.from_struct())

  @spec new_id :: map
  def new_id, do: persistence().new_id()

  @callback new_printable_id :: bitstring
  def new_printable_id, do: persistence().new_printable_id()

  @spec printable_id(any) :: bitstring
  def printable_id(nil), do: ""
  def printable_id(id), do: persistence().printable_id(id)

  @spec object_id(bitstring) :: any
  def object_id(id), do: persistence().object_id(id)

  @spec max_counter_in_events() :: integer
  def max_counter_in_events(), do: persistence().max_counter_in_events()

  @spec events_by_correlation_id(bitstring, integer) :: [map]
  def events_by_correlation_id(correlation_id, after_counter),
    do: persistence().events_by_correlation_id(correlation_id, after_counter)

  @spec event_by_id(bitstring) :: map
  def event_by_id(id),
    do: persistence().event_by_id(id)

  @spec events_by_types([bitstring]) :: [map]
  def events_by_types(types),
    do: persistence().events_by_types(types)

  @spec events() :: [map]
  def events(), do: persistence().events()

  @spec snapshots() :: [map]
  def snapshots(), do: persistence().snapshots()

  @spec get_snapshot(bitstring) :: map | nil
  def get_snapshot(correlation_id), do: persistence().get_snapshot(correlation_id)

  @spec drop_events() :: any
  def drop_events(), do: persistence().drop_events()

  @spec drop_snapshots() :: any
  def drop_snapshots(), do: persistence().drop_snapshots()

  @spec is_valid_id?(any) :: boolean
  def is_valid_id?(id), do: persistence().is_valid_id?(id)

  defp persistence, do: Application.get_env(:seven, :persistence) || Seven.Data.InMemory
end
