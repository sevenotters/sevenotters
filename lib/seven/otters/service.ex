defmodule Seven.Otters.Service do
  @moduledoc false

  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer

      use Seven.Utils.Tagger
      @tag :service

      alias Seven.Utils.Events

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
        {:ok, init_state()}
      end

      def handle_call(:state, _from, state), do: {:reply, state, state}

      def handle_call({:command, command}, _from, state) do
        Seven.Log.debug("#{__MODULE__} received command: #{inspect(command)}")

        case handle_command(command) do
          {:managed, events} ->
            events
            |> Events.set_request_id(command.request_id)
            |> Events.trigger()

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
      end

      def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
        Seven.Log.debug("Dying #{__MODULE__}(#{inspect(pid)}): #{inspect(state)}")
        {:noreply, state}
      end

      def handle_info(msg, state), do: handle_service_info(msg, state)

      # Privates

      @spec create_event(bitstring, map) :: map
      defp create_event(type, payload) do
        Seven.Otters.Event.create(type, payload, __MODULE__)
      end

      @before_compile Seven.Otters.Service
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      defp init_state(), do: %{}
      def route(_command, _params), do: :not_routed
      def handle_service_info(_, state), do: {:noreply, state}
      defp handle_command(command), do: raise("Command #{inspect(command)} is not handled correctly by #{__MODULE__}")
    end
  end
end
