defmodule EventStoreTest do
  use ExUnit.Case, async: true

  @moduledoc false

  alias Seven.TestHelper
  alias Seven.EventStore.EventStore

  test "subscribe and unsubscribe to event" do
    unique_event_name = TestHelper.unique_name()

    # Subscribe
    EventStore.subscribe(unique_event_name, self())
    subscribers = EventStore.state().event_store.event_to_pids
    monitors = EventStore.state().event_store.pid_to_monitor

    assert subscribers[unique_event_name] |> Enum.member?(self())
    refute monitors |> find_in_monitors() |> is_nil()

    # Unsubscribe
    EventStore.unsubscribe(unique_event_name, self())
    subscribers = EventStore.state().event_store.event_to_pids
    monitors = EventStore.state().event_store.pid_to_monitor

    refute subscribers[unique_event_name] |> Enum.member?(self())
    assert monitors |> find_in_monitors() |> is_nil()
  end

  defp find_in_monitors(monitors), do: monitors |> Enum.find(nil, fn {p, _} -> p === self() end)

  defmodule MyProcess do
    use GenServer

    @moduledoc false

    def start_link(), do: GenServer.start(__MODULE__, :ok, [])
    def init(args), do: {:ok, args}
  end

  test "removing dead process from store" do
    {:ok, pid} = MyProcess.start_link()

    unique_event_name = TestHelper.unique_name()
    EventStore.subscribe(unique_event_name, pid)

    Process.exit(pid, :kill)
    refute Process.alive?(pid)

    subscribers = EventStore.state().event_store.event_to_pids
    monitors = EventStore.state().event_store.pid_to_monitor

    refute subscribers[unique_event_name] |> Enum.member?(self())
    assert monitors |> find_in_monitors() |> is_nil()
  end
end
