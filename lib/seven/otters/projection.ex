defmodule Seven.Otters.Projection do
  @moduledoc false

  defmacro __using__(listener_of_events: listener_of_events) do
    quote location: :keep do
      use GenServer
      use Seven.Utils.ListOfMaps

      use Seven.Utils.Tagger
      @tag :projection

      # API
      def start_link(opts \\ []) do
        {:ok, pid} = GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])

        # subscribe my events in store
        unquote(listener_of_events)
        |> Enum.each(&Seven.EventStore.EventStore.subscribe(&1, pid))

        {:ok, pid}
      end

      @spec filter((any -> any)) :: List.t()
      def filter(map_func), do: GenServer.call(__MODULE__, {:filter, map_func})

      @spec query(Atom.t(), Map.t()) :: List.t()
      def query(query_filter, params),
        do: GenServer.call(__MODULE__, {:query, query_filter, params})

      @spec state() :: List.t()
      def state(), do: GenServer.call(__MODULE__, :state)

      @spec pid() :: pid
      def pid, do: GenServer.call(__MODULE__, :pid)

      @spec clean() :: pid
      def clean, do: GenServer.call(__MODULE__, :clean)

      # Callbacks
      def init(:ok) do
        Seven.Log.info("#{__MODULE__} started.")

        state =
          unquote(listener_of_events)
          |> Seven.EventStore.EventStore.events_by_types()
          |> apply_events(initial_state())

        {:ok, state}
      end

      def handle_call({:query, query_filter, params}, _from, state) do
        params = AtomicMap.convert(params, safe: false)

        res =
          case pre_handle_query(query_filter, params, state) do
            :ok -> {:ok, handle_query(query_filter, params, state)}
            err -> err
          end

        {:reply, res, state}
      end

      def handle_call({:filter, filter_func}, _from, state),
        do: {:reply, handle_filter(filter_func, state), state}

      def handle_call(:state, _from, state), do: {:reply, handle_state(state), state}

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

      def handle_info(%Seven.Otters.Event{} = event, state) do
        Seven.Log.event_received(event, __MODULE__)

        {:noreply, handle_event(event, state)}
      end

      def handle_info(_, state), do: {:noreply, state}

      # Privates
      @spec apply_events(List.t(), Map.t()) :: Map.t()
      defp apply_events([], state), do: state

      defp apply_events([event | events], state) do
        Seven.Log.event_received(event, __MODULE__)
        new_state = handle_event(event, state)
        apply_events(events, new_state)
      end

      defp validate(params, schema) do
        case Ve.validate(params, schema) do
          {:ok, _} -> :ok
          err -> err
        end
      end
    end
  end
end
