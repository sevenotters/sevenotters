defmodule Seven.Otters.Service do
  @moduledoc false

  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer

      use Seven.Utils.Tagger
      @tag :service

      # API
      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
      end

      @spec command(Map.t()) :: any
      def command(command), do: GenServer.call(__MODULE__, {:command, command})

      @spec state() :: any
      def state, do: GenServer.call(__MODULE__, :state)

      # Callbacks
      def init(:ok) do
        Seven.Log.info("#{__MODULE__} started.")
        {:ok, initialize()}
      end

      def handle_call(:state, _from, state), do: {:reply, state, state}

      def handle_call({:command, command}, _from, state) do
        Seven.Log.debug("#{__MODULE__} received command: #{inspect(command)}")

        case handle_command(command) do
          {:managed, events} ->
            events
            |> set_request_id(command.request_id)
            |> trigger

            {:reply, :managed, state}

          err ->
            {:reply, err, state}
        end
      end

      def terminate(:normal, _state) do
        Seven.Log.debug("Terminating #{__MODULE__}(#{inspect(self())}) for :normal")
      end

      def terminate(reason, state) do
        Seven.Log.debug("Terminating #{__MODULE__}(#{inspect(self())}) for #{inspect(reason)}")
        IO.inspect("Terminating #{__MODULE__}(#{inspect(self())}) for #{inspect(reason)}")
      end

      def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
        IO.inspect("Dying #{__MODULE__}(#{inspect(pid)}): #{inspect(state)}")
        Seven.Log.debug("Dying #{__MODULE__}(#{inspect(pid)}): #{inspect(state)}")
        {:noreply, state}
      end

      def handle_info(msg, state), do: handle_service_info(msg, state)

      # Privates
      @spec set_request_id(List.t(), String.t()) :: List.t()
      defp set_request_id(events, request_id) when is_list(events),
        do: Enum.map(events, &Map.put(&1, :request_id, request_id))

      @spec create_event(String.t(), Map.t()) :: Map.t()
      defp create_event(type, payload) when is_map(payload) do
        Seven.Otters.Event.create(type, payload)
        |> Map.put(:correlation_module, __MODULE__)
      end

      defp trigger([]), do: :ok

      defp trigger([event | events]) do
        Seven.EventStore.EventStore.fire(event)
        trigger(events)
      end

      defp validate(command, schema) do
        case Ve.validate(command.payload, schema) do
          {:ok, _} -> {:routed, command, __MODULE__}
          {:error, reasons} -> {:routed_but_invalid, reasons |> List.first()}
        end
      end
    end
  end
end
