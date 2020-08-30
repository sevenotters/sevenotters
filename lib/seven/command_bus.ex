defmodule Seven.CommandBus do
  @moduledoc false

  defmodule RequestInfo do
    @moduledoc false

    defstruct managed: :not_routed,
              command_request: nil,
              command: nil,
              handler: nil,
              handler_type: nil

    defdelegate fetch(term, key), to: Map
    defdelegate get(term, key, default), to: Map
    defdelegate get_and_update(term, key, fun), to: Map
  end

  # API
  @spec send_command_request(Seven.CommandRequest.t()) :: any
  def send_command_request(%Seven.CommandRequest{} = command_request) do
    %RequestInfo{managed: :not_routed, command_request: command_request}
    |> route_command(Seven.Entities.aggregates(), :aggregate)
    |> route_command(Seven.Entities.processes(), :process)
    |> route_command(Seven.Entities.services(), :service)
    |> add_meta
    |> log_routing
    |> dispatch_command
  end

  # Privates
  @spec route_command(RequestInfo.t(), List.t(), atom) :: RequestInfo.t()
  defp route_command(%RequestInfo{managed: :routed} = request_info, _handlers, _type),
    do: request_info

  defp route_command(%RequestInfo{} = request_info, [], _type), do: request_info

  defp route_command(%RequestInfo{} = request_info, [handler | handlers], type) do
    case handler.route(request_info.command_request.command, request_info.command_request.params) do
      :not_routed ->
        route_command(request_info, handlers, type)

      {:routed, command, handler} ->
        %{request_info | managed: :routed, command: command, handler: handler, handler_type: type}

      r ->
        %{request_info | managed: r}
    end
  end

  @spec add_meta(RequestInfo.t()) :: RequestInfo.t()
  defp add_meta(%RequestInfo{command: nil} = request_info), do: request_info

  defp add_meta(%RequestInfo{command: command} = request_info) do
    command =
      command
      |> Map.put(:request_id, request_info.command_request.id)
      |> Map.put(:responder_module, request_info.handler)

    Map.put(request_info, :command, command)
  end

  defp log_routing(%RequestInfo{managed: :routed} = request_info) do
    Seven.Log.debug("Command #{request_info.command_request.command} routed by #{request_info.handler}: #{inspect(request_info.command)}")

    request_info
  end

  defp log_routing(%RequestInfo{managed: :not_routed} = request_info) do
    Seven.Log.debug("Command #{request_info.command_request.command} not routed")
    request_info
  end

  defp log_routing(%RequestInfo{managed: {_, reason}} = request_info) do
    Seven.Log.debug("Command #{request_info.command_request.command} routed but invalid: #{inspect(reason)}")

    request_info
  end

  defp dispatch_command(%RequestInfo{managed: :not_routed}), do: :not_managed
  defp dispatch_command(%RequestInfo{managed: {_, _reason} = r}), do: r

  defp dispatch_command(%RequestInfo{managed: :routed, handler_type: :aggregate} = request_info) do
    entity_field = request_info.handler.aggregate_field
    dispatch_command_by_handler(request_info, entity_field)
  end

  defp dispatch_command(%RequestInfo{managed: :routed, handler_type: :process} = request_info) do
    entity_field = request_info.handler.process_field
    dispatch_command_by_handler(request_info, entity_field)
  end

  defp dispatch_command(%RequestInfo{managed: :routed, handler_type: :service} = request_info) do
    Seven.Log.command_received(request_info.command)
    request_info.handler.command(request_info.command)
  end

  defp dispatch_command_by_handler(%RequestInfo{managed: :routed} = request_info, entity_field) do
    case Map.fetch(request_info.command.payload, entity_field) do
      {:ok, persistence_correlation_value_id} ->
        correlation_value_id = Seven.Data.Persistence.printable_id(persistence_correlation_value_id)

        {:ok, pid} = Seven.Registry.get_child(request_info.handler, correlation_value_id)
        Seven.Log.command_received(request_info.command)

        request_info = put_in(request_info, [:command, :process_id], correlation_value_id)
        request_info.handler.command(pid, request_info.command)

      :error ->
        Seven.Log.error("Error applying command #{request_info.command.type}: missing #{entity_field} in #{inspect(request_info.command.payload)}")

        :not_managed
    end
  end
end
