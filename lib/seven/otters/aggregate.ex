defmodule Seven.Otters.Aggregate do
  @moduledoc """
  Provides the ``use`` macro to create an aggregate.

  Example:

      defmodule SevenCommerce.Aggregates.User do
        use Seven.Otters.Aggregate, aggregate_field: :id

        defstruct id: nil,
                  user: nil,
                  password: nil,
                  cart: []

        defp init_state, do: %__MODULE__{}

        defp pre_handle_command(_command, _state), do: :ok
        defp handle_command(_command, _state), do: {:managed, []}
        defp handle_event(_event, state), do: state
      end

  Module must declare the use of `Seven.Otters.Aggregate` module, specifying the field to use as correlation id;
  the field must be present in module structure:

      use Seven.Otters.Aggregate, aggregate_field: :id

      defstruct id: nil,
                ...

  Some function must be implemented in the aggregate.
  """

  defmacro __using__(aggregate_field: aggregate_field) do
    quote location: :keep do
      use GenServer

      @test_env Mix.env() == :test

      use Seven.Utils.Tagger
      @tag :aggregate

      @max_lifetime_minutes Application.get_env(:seven, :aggregate_lifetime) || 60
      @lifetime_minutes_check div(@max_lifetime_minutes, 2)

      alias Seven.Utils.{Events, Snapshot}

      def command_timeout, do: 5_000
      defoverridable command_timeout: 0

      # API
      def aggregate_field, do: unquote(aggregate_field)

      def start_link(correlation_id, opts \\ []) do
        {:ok, pid} = GenServer.start_link(__MODULE__, correlation_id, opts)

        Seven.Log.debug("Max aggregates lifetime: #{@max_lifetime_minutes} minutes")
        Seven.Log.debug("Aggregates lifetime check: #{@lifetime_minutes_check} minutes")
        verify_alive(pid)

        {:ok, pid}
      end

      @spec command(pid, map) :: any
      def command(pid, command) do
        try do
          GenServer.call(pid, {:command, command}, command_timeout())
        catch
          :exit, {:noproc, _} ->
            Seven.Log.error("""
            Call to dead aggregate: it happens when aggregate has just been killed
            but not removed yet from Registry
            """)
        end
      end

      @spec state(pid) :: any
      def state(pid), do: GenServer.call(pid, :state)

      @spec data(pid) :: any
      def data(pid), do: GenServer.call(pid, :data)

      if @test_env do
        @spec send(Seven.Otters.Event, atom) :: pid
        def send(%Seven.Otters.Event{} = e, pid), do: GenServer.call(pid, {:send, e})
      end

      # Callbacks
      def init(correlation_id), do: {:ok, correlation_id, {:continue, :rehydrate}}

      def handle_continue(:rehydrate, correlation_id) do
        Seven.Log.debug("Init (#{inspect(self())}): #{inspect(correlation_id)}")

        {state, snapshot} = rehydrate(correlation_id, Snapshot.get_snap(correlation_id, &read_snapshot/1))

        {:noreply,
         %{
           correlation_id: correlation_id,
           internal_state: state,
           last_touch: DateTime.utc_now(),
           snapshot: snapshot
         }}
      end

      def handle_call(:state, _from, state), do: {:reply, state, state}

      def handle_call(:data, _from, %{internal_state: internal_state} = state),
        do: {:reply, internal_state, state}

      def handle_call({:command, command}, _from, %{internal_state: internal_state} = state) do
        Seven.Log.debug("#{__MODULE__} received command: #{inspect(command)}")

        state = %{state | last_touch: DateTime.utc_now()}

        case pre_handle_command(command, internal_state) do
          :ok ->
            command_internal(command, state)

          err ->
            err = after_command(err)
            {:reply, err, state}
        end
      end

      if @test_env do
        def handle_call({:send, event}, _from, %{correlation_id: correlation_id, internal_state: internal_state} = state) do
          event = Events.set_correlation_id(event, correlation_id)

          Seven.Log.event_received(event, __MODULE__)
          new_internal_state = handle_event(event, internal_state)

          {:reply, :managed, %{state | internal_state: new_internal_state}}
        end
      end

      def terminate(:normal, _state) do
        Seven.Log.debug("Terminating #{__MODULE__}(#{inspect(self())}) for :normal")
      end

      def terminate(reason, _state) do
        Seven.Log.debug("Terminating #{__MODULE__}(#{inspect(self())}) for #{inspect(reason)}")
      end

      def handle_info(:useless, state) do
        Seven.Log.debug("Useless #{__MODULE__}")
        {:stop, :normal, state}
      end

      def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
        Seven.Log.debug("Dying #{__MODULE__}(#{inspect(pid)}): #{inspect(state)}")
        {:noreply, state}
      end

      def handle_info(:verify_alive, %{last_touch: last_touch} = state) do
        minutes = DateTime.diff(DateTime.utc_now(), last_touch, :second)

        case minutes > @max_lifetime_minutes do
          true ->
            {:ok, aggr_field} = Map.fetch(state.internal_state, aggregate_field())

            Seven.Log.debug("Closing aggregate #{__MODULE__} for #{minutes} minutes of inactivity (#{aggregate_field()}: #{aggr_field}).")

            {:stop, :normal, state}

          _ ->
            verify_alive(self())
            {:noreply, state}
        end
      end

      def handle_info(_, state), do: {:noreply, state}

      # Privates
      defp command_internal(command, state) do
        case handle_command(command, state.internal_state) do
          {:managed, events} ->
            events =
              events
              |> Events.set_request_id(command.request_id)
              |> Events.set_correlation_id(state.correlation_id)
              |> Events.set_process_id(command.process_id)

            new_internal_state = apply_events(events, state.internal_state)
            Events.trigger(events)

            snapshot =
              state.snapshot
              |> Snapshot.add_events(events)
              |> Snapshot.snap_if_needed(new_internal_state, &write_snapshot/2)

            {:reply, :managed, %{state | internal_state: new_internal_state, snapshot: snapshot}}

          err ->
            err = after_command(err)
            {:reply, err, state}
        end
      end

      @spec verify_alive(PID.t()) :: any
      defp verify_alive(pid),
        do: Process.send_after(pid, :verify_alive, @lifetime_minutes_check * 60_000)

      @spec create_event(bitstring, map) :: map
      defp create_event(type, payload) do
        Seven.Otters.Event.create(type, payload, __MODULE__)
      end

      @spec apply_events([Seven.Otters.Event.t()], Map.t()) :: Map.t()
      defp apply_events([], state), do: state

      defp apply_events([event | events], state) do
        Seven.Log.event_received(event, __MODULE__)
        new_state = handle_event(event, state)
        apply_events(events, new_state)
      end

      defp after_command({:no_aggregate, msg}) do
        Seven.Log.debug("No aggregate to keep: send :useless to #{__MODULE__}")
        Process.send(self(), :useless, [])
        msg
      end

      defp after_command(err), do: err

      defp rehydrate(correlation_id, nil) do
        events =
          correlation_id
          |> Seven.EventStore.EventStore.events_by_correlation_id()
          |> Seven.EventStore.EventStore.events_stream_to_list()

        Seven.Log.info("Processing #{length(events)} events for #{inspect(correlation_id)}.")
        state = apply_events(events, init_state())

        Seven.Log.info("#{inspect(correlation_id)} rehydrated.")

        snapshot =
          Snapshot.new(correlation_id)
          |> Snapshot.add_events(events)

        {state, snapshot}
      end

      defp rehydrate(correlation_id, snapshot) do
        snapshot = struct(Snapshot, snapshot)
        last_seen_event = Seven.EventStore.EventStore.event_by_id(snapshot.last_event_id)
        new_events =
          correlation_id
          |> Seven.EventStore.EventStore.events_by_correlation_id(last_seen_event.counter)
          |> Seven.EventStore.EventStore.events_stream_to_list()

        Seven.Log.info("Processing #{length(new_events)} events for #{inspect(correlation_id)}.")
        state = apply_events(new_events, Snapshot.get_state(snapshot.state))

        Seven.Log.info("#{inspect(correlation_id)} rehydrated.")

        snapshot =
          Snapshot.new(snapshot)
          |> Snapshot.add_events(new_events)

        {state, snapshot}
      end

      @before_compile Seven.Otters.Aggregate
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      def route(_command, _params), do: :not_routed

      @spec pre_handle_command(Seven.Otters.Command.t(), any) :: any
      defp pre_handle_command(_command, _state), do: :ok

      @spec handle_command(Seven.Otters.Command.t(), any) :: any
      defp handle_command(command, _state), do: raise("Command #{inspect(command)} is not handled correctly by #{__MODULE__}")

      @spec handle_event(Seven.Otters.Event.t(), any) :: any
      defp handle_event(event, _state), do: raise("Event #{inspect(event)} is not handled correctly by #{__MODULE__}")

      defp read_snapshot(correlation_id), do: nil
      defp write_snapshot(correlation_id, snapshot), do: nil
    end
  end
end
