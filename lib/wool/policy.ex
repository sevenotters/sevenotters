defmodule Seven.Policy do
  @moduledoc false

  defmacro __using__(listener_of_events: listener_of_events) do
    quote location: :keep do
      use GenServer

      use Seven.Utils.Tagger
      @tag :policy

      # API
      def start_link(opts \\ []) do
        {:ok, pid} = GenServer.start_link(__MODULE__, {:ok, nil}, opts ++ [name: __MODULE__])

        # subscribe my events in store
        unquote(listener_of_events)
        |> Enum.each(&Seven.EventStore.subscribe(&1, pid))

        {:ok, pid}
      end

      # Callbacks
      def init({:ok, state}) do
        Seven.Log.info("#{__MODULE__} started.")
        {:ok, state}
      end

      def handle_info(%Seven.Event{} = event, state) do
        Seven.Log.event_received(event, __MODULE__)

        handle_event(event)
        |> Enum.map(&Seven.Log.command_request_sent/1)
        |> Enum.each(&Seven.CommandBus.send_command_request/1)

        {:noreply, state}
      end
      def handle_info(_, state), do: {:noreply, state}

      # Privates
    end
  end
end
