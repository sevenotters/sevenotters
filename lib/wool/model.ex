defmodule Seven.Model do
  @moduledoc false

  defmacro __using__(listener_of_events: listener_of_events) do
    quote location: :keep do
      use GenServer
      use Seven.Utils.ListOfMaps

      use Seven.Utils.Tagger
      @tag :model

      # API
      def start_link(opts \\ []) do
        {:ok, pid} = GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])

        # subscribe my events in store
        unquote(listener_of_events)
        |> Enum.each(&Seven.EventStore.subscribe(&1, pid))

        {:ok, pid}
      end

      @spec filter((any -> any)) :: List.t()
      def filter(map_func), do: GenServer.call(__MODULE__, {:filter, map_func})

      @spec find((any -> any)) :: any
      def find(map_func), do: GenServer.call(__MODULE__, {:find, map_func})

      @spec state() :: any
      def state(), do: GenServer.call(__MODULE__, :state)

      @spec set_state(any) :: any
      def set_state(state), do: GenServer.call(__MODULE__, {:set_state, state})

      @spec pid() :: pid
      def pid, do: GenServer.call(__MODULE__, :pid)

      @spec clean() :: pid
      def clean, do: GenServer.call(__MODULE__, :clean)

      # Callbacks
      def init(:ok) do
        Seven.Log.info("#{__MODULE__} started.")

        state =
          unquote(listener_of_events)
          |> Seven.EventStore.events_by_types()
          |> apply_events(initial_state())

        {:ok, state}
      end

      def handle_call({:find, find_func}, _from, state),
        do: {:reply, handle_find(find_func, state), state}

      def handle_call({:filter, filter_func}, _from, state),
        do: {:reply, handle_filter(filter_func, state), state}

      def handle_call(:state, _from, state), do: {:reply, handle_state(state), state}

      def handle_call({:set_state, new_state}, _from, _state), do: {:reply, :ok, new_state}

      def handle_call(:pid, _from, state), do: {:reply, self(), state}
      def handle_call(:clean, _from, state), do: {:reply, :ok, initial_state()}

      def terminate(:normal, _state) do
        Seven.Log.debug("Terminating #{__MODULE__}(#{inspect(self())}) for :normal")
      end
      def terminate(reason, _state) do
        Seven.Log.debug("Terminating #{__MODULE__}(#{inspect(self())}) for #{inspect(reason)}")
        IO.inspect("Terminating #{__MODULE__}(#{inspect(self())}) for #{inspect(reason)}")
      end

      def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
        IO.inspect("Dying #{__MODULE__}(#{inspect(pid)}): #{inspect(state)}")
        Seven.Log.debug("Dying #{__MODULE__}(#{inspect(pid)}): #{inspect(state)}")
        {:noreply, state}
      end
      def handle_info(%Seven.Event{} = event, state) do
        Seven.Log.event_received(event, __MODULE__)

        {:noreply, handle_event(event, state)}
      end
      def handle_info(_, state), do: {:noreply, state}

      # Privates
      @spec apply_events(List.t(), any) :: any
      defp apply_events([], state), do: state

      defp apply_events([event | events], state) do
        Seven.Log.event_received(event, __MODULE__)
        new_state = handle_event(event, state)
        apply_events(events, new_state)
      end
    end
  end
end
