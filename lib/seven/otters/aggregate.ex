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

      use Seven.Utils.Tagger
      @tag :aggregate

      @max_lifetime_minutes Application.get_env(:seven, :aggregate_lifetime) || 60
      @lifetime_minutes_check div(@max_lifetime_minutes, 2)

      # API
      def aggregate_field, do: unquote(aggregate_field)

      def start_link(correlation_id, opts \\ []) do
        {:ok, pid} = GenServer.start_link(__MODULE__, correlation_id, opts)

        Seven.Log.debug("Max aggregates lifetime: #{@max_lifetime_minutes} minutes")
        Seven.Log.debug("Aggregates lifetime check: #{@lifetime_minutes_check} minutes")
        verify_alive(pid)

        {:ok, pid}
      end

      @spec command(PID.t(), Map.t()) :: any
      def command(pid, command), do: GenServer.call(pid, {:command, command})

      @spec state(pid) :: any
      def state(pid), do: GenServer.call(pid, :state)

      @spec data(pid) :: any
      def data(pid), do: GenServer.call(pid, :data)

      # Callbacks
      def init(correlation_id), do: {:ok, correlation_id, {:continue, :rehydrate}}

      def handle_continue(:rehydrate, correlation_id) do
        Seven.Log.debug("Init (#{inspect(self())}): #{inspect(correlation_id)}")

        events = Seven.EventStore.EventStore.events_by_correlation_id(correlation_id)

        Seven.Log.info("Processing #{length(events)} events for #{inspect(correlation_id)}.")
        state = events |> apply_events(init_state())

        Seven.Log.info("#{inspect(correlation_id)} rehydrated.")

        {:noreply,
          %{
            correlation_id: correlation_id,
            internal_state: state,
            last_touch: DateTime.now!("Etc/UTC")
          }
        }
      end

      def handle_call(:state, _from, state), do: {:reply, state, state}

      def handle_call(:data, _from, %{internal_state: internal_state} = state),
        do: {:reply, internal_state, state}

      def handle_call({:command, command}, _from, %{internal_state: internal_state} = state) do
        Seven.Log.debug("#{__MODULE__} received command: #{inspect(command)}")

        state = %{state | last_touch: DateTime.now!("Etc/UTC")}

        case pre_handle_command(command, internal_state) do
          :ok -> command_internal(command, state)
          err ->
            err = after_command(err)
            {:reply, err, state}
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
        minutes = DateTime.diff(DateTime.now!("Etc/UTC"), last_touch, :second)

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
      defp command_internal(
             command,
             %{correlation_id: correlation_id, internal_state: internal_state} = state
           ) do
        case handle_command(command, internal_state) do
          {:managed, events} ->
            events =
              events
              |> set_request_id(command.request_id)
              |> set_correlation_id(correlation_id)

            new_internal_state = apply_events(events, internal_state)
            trigger(events)

            {:reply, :managed, %{state | internal_state: new_internal_state}}

          err ->
            err = after_command(err)
            {:reply, err, state}
        end
      end

      @spec verify_alive(PID.t()) :: any
      defp verify_alive(pid),
        do: Process.send_after(pid, :verify_alive, @lifetime_minutes_check * 60_000)

      @spec set_request_id(List.t(), String.t()) :: List.t()
      defp set_request_id(events, request_id) when is_list(events),
        do: Enum.map(events, &Map.put(&1, :request_id, request_id))

      @spec set_correlation_id(List.t(), Map.t()) :: List.t()
      defp set_correlation_id(events, correlation_id) when is_list(events) do
        events |> Enum.map(fn e -> Map.put(e, :correlation_id, correlation_id) end)
      end

      @spec create_event(String.t(), Map.t()) :: Map.t()
      defp create_event(type, payload) when is_map(payload) do
        Seven.Otters.Event.create(type, payload, __MODULE__)
      end

      @spec apply_events([Seven.Otters.Event.t()], Map.t()) :: Map.t()
      defp apply_events([], state), do: state

      defp apply_events([event | events], state) do
        Seven.Log.event_received(event, __MODULE__)
        new_state = handle_event(event, state)
        apply_events(events, new_state)
      end

      defp trigger([]), do: :ok

      defp trigger([event | events]) do
        Seven.EventStore.EventStore.fire(event)
        trigger(events)
      end

      defp after_command({:no_aggregate, msg}) do
        Seven.Log.debug("No aggregate to keep: send :useless to #{__MODULE__}")
        Process.send(self(), :useless, [])
        msg
      end
      defp after_command(err), do: err

      @before_compile Seven.Otters.Aggregate
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      def route(_command, _params), do: :not_routed

      @spec pre_handle_command(Seven.Otters.Command.t(), any) :: any
      defp pre_handle_command(_command, _state), do: :ok

      @spec handle_command(Seven.Otters.Command.t(), any) :: any
      defp handle_command(command, _state), do: raise "Command #{inspect command} is not handled correctly by #{__MODULE__}"

      @spec handle_event(Seven.Otters.Event.t(), any) :: any
      defp handle_event(event, _state), do: raise "Event #{inspect event} is not handled correctly by #{__MODULE__}"
    end
  end
end
