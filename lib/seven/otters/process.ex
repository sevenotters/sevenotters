defmodule Seven.Otters.Process do
  @moduledoc false

  defmacro __using__(process_field: process_field) do
    quote location: :keep do
      use GenServer

      use Seven.Utils.Tagger
      @tag :process

      # API
      def process_field, do: unquote(process_field)

      def start_link(process_id, opts \\ []) do
        GenServer.start_link(__MODULE__, process_id, opts)
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

        case handle_command(command, state.internal_state) do
          {:continue, events, new_internal_state} ->
            state = %{state | internal_state: new_internal_state}

            events =
              events
              |> set_request_id(command.request_id)
              |> set_correlation_id(state.process_id)

            trigger(events)


            {:reply, :managed, state}

          {:stop, _events} ->
            # TODO: stop this process
            {:reply, :stop, state}

          err ->
            {:reply, err, state}
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

      def handle_info(_, state), do: {:noreply, state}

      # Privates

      @spec create_event(bitstring, map) :: map
      defp create_event(type, payload) do
        Seven.Otters.Event.create(type, payload, __MODULE__)
      end

      @spec set_request_id([Seven.Otters.Event], bitstring) :: [Seven.Otters.Event]
      defp set_request_id(events, request_id),
        do: Enum.map(events, &Map.put(&1, :request_id, request_id))

      @spec set_correlation_id([Seven.Otters.Event] | Seven.Otters.Event, bitstring) :: [Seven.Otters.Event]
      defp set_correlation_id(events, correlation_id) when is_list(events) do
        Enum.map(events, fn e -> set_correlation_id(e, correlation_id) end)
      end

      defp set_correlation_id(event, correlation_id) do
        event
        |> Map.put(:correlation_id, correlation_id)
        |> Map.put(:process_id, correlation_id)
      end

      defp send_command(%Seven.CommandRequest{} = request, state) do
        {:ok, proc_field} = Map.fetch(state, process_field())

        %{request | id: Seven.Data.Persistence.new_id() |> Seven.Data.Persistence.printable_id(), process_id: proc_field, sender: __MODULE__}
        |> Seven.CommandBus.send_command_request()
      end

      defp trigger([]), do: :ok

      defp trigger([event | events]) do
        Seven.EventStore.EventStore.fire(event)
        trigger(events)
      end

      @before_compile Seven.Otters.Process
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      defp handle_command(command), do: raise("Command #{inspect(command)} is not handled correctly by #{__MODULE__}")
    end
  end
end
