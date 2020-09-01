defmodule Seven.Test.Helper do
  @moduledoc false

  def wait(time \\ 50), do: :timer.sleep(time)
  def unique_name, do: UUID.uuid4(:hex)
  def unique_email, do: UUID.uuid4(:hex) <> "@gmail.com"
  def unique_id, do: UUID.uuid4(:hex) |> String.slice(0, 24)

  def drop_events, do: Seven.Data.Persistence.drop_events()
  def drop_snapshots, do: Seven.Data.Persistence.drop_snapshots()

  def clean_projections do
    # Projections can be already loaded before cleaning events, clean it
    Seven.Entities.projections() |> Enum.each(fn {_, module} -> module.clean() end)
  end

  def events_by_request(request_id),
    do: Seven.EventStore.EventStore.state().events |> Enum.filter(&(&1["request_id"] == request_id))

  def contains?(events, f), do: events |> Enum.find(nil, fn e -> f.(e) end) != nil

  def events_by_request_and_type(request_id, type),
    do:
      Seven.EventStore.EventStore.state().events
      |> Enum.filter(&(&1["request_id"] == request_id and &1["type"] == type))

  def send_command_request(%Seven.CommandRequest{} = request) do
    request
    |> Seven.Log.command_request_sent()
    |> Seven.CommandBus.send_command_request()
  end

  def get_aggregate_state(aggregate_type, correlation_key) do
    {:ok, pid} = Seven.Registry.get_aggregate(aggregate_type, correlation_key)
    aggregate_type.state(pid).internal_state
  end
end
