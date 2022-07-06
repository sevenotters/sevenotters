defmodule Seven.Data.PersistenceBehaviour do
  @moduledoc false

  @callback initialize() :: any
  @callback insert_event(map) :: any
  @callback upsert_process(bitstring, map) :: any
  @callback upsert_services(bitstring, map) :: any
  @callback new_id :: any
  @callback new_printable_id :: bitstring
  @callback object_id(bitstring) :: any
  @callback printable_id(any) :: bitstring
  @callback is_valid_id?(any) :: boolean
  @callback max_counter_in_events() :: integer
  @callback drop_events() :: any
  @callback drop_processes() :: any

  @callback events_reduce(any, any, fun()) :: any

  @callback event_by_id(bitstring) :: map
  @callback events_by_correlation_id(bitstring, integer) :: [map]
  @callback events_by_types([bitstring], integer) :: any
  @callback events() :: [map]
  @callback processes() :: [map]
  @callback get_process(bitstring) :: map | nil
  @callback get_service(bitstring) :: map | nil

  @callback processes_id_by_status(bitstring) :: [map]
end
