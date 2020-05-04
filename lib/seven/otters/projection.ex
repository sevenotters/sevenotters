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

        # subscribe my events in store [TODO: put in init()]
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
      def init(:ok), do: {:ok, nil, {:continue, :rehydrate}}

      def handle_continue(:rehydrate, _state) do
        Seven.Log.info("#{__MODULE__} started.")

        events =
          unquote(listener_of_events)
          |> Seven.EventStore.EventStore.events_by_types()

        Seven.Log.info("Processing #{length(events)} events for #{__MODULE__}.")
        state = events |> apply_events(initial_state())

        Seven.Log.info("#{__MODULE__} rehydrated")

        {:noreply, state}
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
        do: {:reply, state |> Enum.filter(filter_func), state}

      def handle_call(:state, _from, state), do: {:reply, state, state}

      def handle_call(:pid, _from, state), do: {:reply, self(), state}
      def handle_call(:clean, _from, state), do: {:reply, :ok, initial_state()}

      def terminate(:normal, _state) do
        Seven.Log.debug("Terminating #{__MODULE__}(#{inspect(self())}) for :normal")
      end

      def terminate(reason, _state) do
        Seven.Log.debug("Terminating #{__MODULE__}(#{inspect(self())}) for #{inspect(reason)}")
      end

      def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
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

      @before_compile Seven.Otters.Projection
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      defp handle_event(event, _state), do: raise "Event #{inspect event} is not handled correctly by #{__MODULE__}"
      defp pre_handle_query(query, _params, _state), do: raise "Query #{inspect query} is not handled correctly by #{__MODULE__}: missing pre_handle_query()"
      defp handle_query(query, _params, state), do: raise "Query #{inspect query} is not handled correctly by #{__MODULE__}: missing handle_query()"
    end
  end
end
