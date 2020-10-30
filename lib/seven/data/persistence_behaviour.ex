defmodule Seven.Data.PersistenceBehaviour do
  @moduledoc false

  @callback initialize() :: any
  @callback insert_event(map) :: any
  @callback upsert_snapshot(bitstring, map) :: any
  @callback upsert_process(bitstring, map) :: any
  @callback new_id :: any
  @callback new_printable_id :: bitstring
  @callback object_id(bitstring) :: any
  @callback printable_id(any) :: bitstring
  @callback is_valid_id?(any) :: boolean
  @callback max_counter_in_events() :: integer
  @callback drop_events() :: any
  @callback drop_snapshots() :: any
  @callback drop_processes() :: any

  @callback stream_to_list(any) :: [map]

  @callback event_by_id(bitstring) :: map
  @callback events_by_correlation_id(bitstring, integer) :: [map]
  @callback events_by_types([bitstring], integer) :: any
  @callback events() :: [map]
  @callback snapshots() :: [map]
  @callback get_snapshot(bitstring) :: map | nil
  @callback processes() :: [map]
  @callback get_process(bitstring) :: map | nil

  @callback processes_id_by_status(bitstring) :: [map]
end
