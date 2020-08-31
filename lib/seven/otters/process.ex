defmodule Seven.Otters.Process do
  @moduledoc false

  defmacro __using__(process_field: process_field, listener_of_events: listener_of_events) do
    quote location: :keep do
      use GenServer

      use Seven.Utils.Tagger
      @tag :process

      alias Seven.Utils.Events

      # API
      def process_field, do: unquote(process_field)

      def start_link(process_id, opts \\ []) do
        {:ok, pid} = GenServer.start_link(__MODULE__, process_id, opts)

        subscribe_to_es(pid)

        {:ok, pid}
      end

      @spec command(pid, map) :: any
      def command(pid, command), do: GenServer.call(pid, {:command, command})

      @spec state(pid) :: any
      def state(pid), do: GenServer.call(pid, :state)

      # Callbacks
      def init(process_id) do
        Seven.Log.debug("Init (#{inspect(self())}): #{inspect(process_id)}")

        state = %{
          process_id: process_id,
          internal_state: init_state()
        }

        {:ok, state}
      end

      def handle_call(:state, _from, state), do: {:reply, state, state}

      def handle_call({:command, command}, _from, state) do
        Seven.Log.debug("#{__MODULE__} received command: #{inspect(command)}")

        case handle_command(command, state.process_id, state.internal_state) do
          {:continue, events, new_internal_state} ->
            state = %{state | internal_state: new_internal_state}
            trigger_events(events, command.request_id, state.process_id)
            {:reply, :managed, state}

          {:stop, events, new_internal_state} ->
            state = %{state | internal_state: new_internal_state}
            trigger_events(events, command.request_id, state.process_id)
            unsubscribe_from_es(self())
            {:stop, :normal, :stop, state}

          {:error, reason, events, new_internal_state} ->
            state = %{state | internal_state: new_internal_state}
            trigger_events(events, command.request_id, state.process_id)
            unsubscribe_from_es(self())
            {:stop, :normal, {:error, reason}, state}
        end
      end

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

      # incoming events must match with the originating process id
      def handle_info(%Seven.Otters.Event{process_id: process_id} = event, %{internal_state: internal_state, process_id: process_id} = state) do
        Seven.Log.event_received(event, __MODULE__)

        {next_operation, events, new_internal_state} = handle_event(event, internal_state)
        state = %{state | internal_state: new_internal_state}
        trigger_events(events, event.request_id, state.process_id)

        case next_operation do
          :continue ->
            {:noreply, state}
          :stop ->
            unsubscribe_from_es(self())
            {:stop, :normal, state}
        end
      end

      def handle_info(_, state), do: {:noreply, state}

      # Privates

      defp subscribe_to_es(pid) do
        unquote(listener_of_events)
        |> Enum.each(&Seven.EventStore.EventStore.subscribe(&1, pid))
      end

      defp unsubscribe_from_es(pid) do
        unquote(listener_of_events)
        |> Enum.each(&Seven.EventStore.EventStore.unsubscribe(&1, pid))
      end

      defp trigger_events(events, request_id, process_id) do
        events
        |> Events.set_request_id(request_id)
        |> Events.set_correlation_id(process_id)
        |> Events.set_process_id(process_id)
        |> Events.trigger()
      end

      @spec create_event(bitstring, map) :: map
      defp create_event(type, payload) do
        Seven.Otters.Event.create(type, payload, __MODULE__)
      end

      defp send_command(%Seven.CommandRequest{} = request, state) do
        %{request | sender: __MODULE__}
        |> Seven.CommandBus.send_command_request()
      end

      defp registered_name() do
        {:registered_name, name} = Process.info(self(), :registered_name)
        name
      end

      @before_compile Seven.Otters.Process
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      def route(_command, _params), do: :not_routed
      defp handle_event(event, _state), do: raise("Event #{inspect(event)} is not handled correctly by #{registered_name()}")
      defp handle_command(command), do: raise("Command #{inspect(command)} is not handled correctly by #{__MODULE__}")
    end
  end
end
