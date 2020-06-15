defmodule Seven.Otters.Projection do
  @moduledoc false

  defmacro __using__(listener_of_events: listener_of_events) do
    quote location: :keep do
      use GenServer

      @test_env Mix.env() == :test

      use Seven.Utils.Tagger
      @tag :projection

      # API
      def start_link(opts \\ []) do
        projection_name = Keyword.get(opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, opts, opts ++ [name: projection_name])
      end

      @spec filter((any -> any), atom) :: List.t()
      def filter(map_func, process_name \\ __MODULE__), do: GenServer.call(process_name, {:filter, map_func})

      @spec query(Atom.t(), Map.t(), atom) :: List.t()
      def query(query_filter, params, process_name \\ __MODULE__),
        do: GenServer.call(process_name, {:query, query_filter, params})

      @spec state(atom) :: List.t()
      def state(process_name \\ __MODULE__), do: GenServer.call(process_name, :state)

      @spec pid(atom) :: pid
      def pid(process_name \\ __MODULE__), do: GenServer.call(process_name, :pid)

      @spec clean(atom) :: pid
      def clean(process_name \\ __MODULE__), do: GenServer.call(process_name, :clean)

if @test_env do
      @spec send(Seven.Otters.Event, atom) :: pid
      def send(%Seven.Otters.Event{} = e, process_name \\ __MODULE__), do: GenServer.call(process_name, {:send, e})
end
      #
      # Callbacks
      #
      def init(opts), do: {:ok, opts, {:continue, :rehydrate}}

      def handle_continue(:rehydrate, opts) do
        Seven.Log.info("Projection #{registered_name()} started.")

        state =
          Keyword.get(opts, :subscribe_to_eventstore, true)
          |> subscribe_and_rehydratate()

        {:noreply, state}
      end

      def handle_call({:query, query_filter, params}, _from, state) do
        params = AtomicMap.convert(params, safe: false)

        res =
          case pre_handle_query(query_filter, params, state) do
            :ok -> handle_query(query_filter, params, state)
            err -> err
          end

        {:reply, res, state}
      end

      def handle_call({:filter, filter_func}, _from, state),
        do: {:reply, state |> Enum.filter(filter_func), state}

      def handle_call(:state, _from, state), do: {:reply, state, state}

      def handle_call(:pid, _from, state), do: {:reply, self(), state}
      def handle_call(:clean, _from, state), do: {:reply, :ok, init_state()}

      def handle_call({:send, event}, _from, state) do
        Seven.Log.event_received(event, registered_name())
        {:reply, event, handle_event(event, state)}
      end

      def terminate(:normal, _state) do
        Seven.Log.debug("Terminating #{registered_name()}(#{inspect(self())}) for :normal")
      end

      def terminate(reason, _state) do
        Seven.Log.debug("Terminating #{registered_name()}(#{inspect(self())}) for #{inspect(reason)}")
      end

      def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
        Seven.Log.debug("Dying #{registered_name()}(#{inspect(pid)}): #{inspect(state)}")
        {:noreply, state}
      end

      def handle_info(%Seven.Otters.Event{} = event, state) do
        Seven.Log.event_received(event, registered_name())

        {:noreply, handle_event(event, state)}
      end

      def handle_info(_, state), do: {:noreply, state}

      #
      # Privates
      #
      @spec apply_events(List.t(), Map.t()) :: Map.t()
      defp apply_events([], state), do: state

      defp apply_events([event | events], state) do
        Seven.Log.event_received(event, registered_name())
        new_state = handle_event(event, state)
        apply_events(events, new_state)
      end

      defp subscribe_and_rehydratate(true) do
        unquote(listener_of_events)
        |> Enum.each(&Seven.EventStore.EventStore.subscribe(&1, self()))

        events =
          unquote(listener_of_events)
          |> Seven.EventStore.EventStore.events_by_types()

        Seven.Log.info("Processing #{length(events)} events for #{registered_name()}.")
        state = events |> apply_events(init_state())

        Seven.Log.info("Projection #{registered_name()} rehydrated")

        state
      end
      defp subscribe_and_rehydratate(_) do
        Seven.Log.info("Projection #{registered_name()} is not subscribed to EventStore.")
        init_state()
      end

      defp registered_name() do
        {:registered_name, name} = Process.info(self(), :registered_name)
        name
      end

      @before_compile Seven.Otters.Projection
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      defp handle_event(event, _state), do: raise "Event #{inspect event} is not handled correctly by #{registered_name()}"
      defp pre_handle_query(query, _params, _state), do: raise "Query #{inspect query} does not exist in #{registered_name()}: missing pre_handle_query()"
      defp handle_query(query, _params, state), do: raise "Query #{inspect query} does not exist in #{registered_name()}: missing handle_query()"
    end
  end
end
