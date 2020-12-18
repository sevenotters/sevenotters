defmodule Seven.Log do
  require Logger

  @moduledoc false

  # TODO: migrate in GenServer?

  def debug(msg) when is_bitstring(msg) do
    Logger.debug(fn -> msg end)
  end

  def info(msg) when is_bitstring(msg), do: Logger.info(fn -> msg end)
  def warning(msg) when is_bitstring(msg), do: Logger.warn(fn -> msg end)
  def error(msg) when is_bitstring(msg), do: Logger.error(fn -> msg end)

  @spec command_received(Seven.Otters.Command.t()) :: Seven.Otters.Command.t()
  def command_received(%Seven.Otters.Command{} = command) do
    if Application.get_env(:seven, :print_commands) do
      Bunt.puts([
        :steelblue,
        "#{command.request_id}: [cr] #{command.type} - received by: #{command.responder_module}, payload: #{command.payload |> filter_data() |> inspect}"
      ])
    end

    command
  end

  @spec command_request_sent(Seven.CommandRequest.t()) :: Seven.CommandRequest.t()
  def command_request_sent(%Seven.CommandRequest{} = request) do
    if Application.get_env(:seven, :print_commands) do
      Bunt.puts([
        :steelblue,
        "________________________________: [cs] #{request.command} - sent by: #{request.sender}, params: #{request.command.payload |> filter_data() |> inspect}"
      ])
    end

    request
  end

  @spec event_received(Seven.Otters.Event.t(), Atom.t()) :: Seven.Otters.Event.t()
  def event_received(%Seven.Otters.Event{} = event, module) do
    if Application.get_env(:seven, :print_events) do
      Bunt.puts([
        :orange,
        "#{Seven.Data.Persistence.printable_id(event.request_id)}: [er] #{event.type} - received by: #{module},
        id: \"#{Seven.Data.Persistence.printable_id(event.correlation_id)}\", payload: #{event.payload |> filter_data() |> inspect}"
      ])
    end

    event
  end

  @spec event_fired(Seven.Otters.Event.t()) :: Seven.Otters.Event.t()
  def event_fired(%Seven.Otters.Event{} = event) do
    if Application.get_env(:seven, :print_events) do
      Bunt.puts([
        :orange,
        "#{Seven.Data.Persistence.printable_id(event.request_id)}: [ef] #{event.type} - fired by: #{event.correlation_module},
        id: \"#{Seven.Data.Persistence.printable_id(event.correlation_id)}\", payload: #{event.payload |> filter_data() |> inspect}"
      ])
    end

    event
  end

  defp filter_data(m) when is_struct(m), do: filter_data(Map.from_struct(m))

  defp filter_data(m) when is_map(m) do
    Enum.map(m, fn
      {k, v} when is_map(v) -> filter(k, filter_data(v))
      {k, v} -> filter(k, v)
    end)
  end

  defp filter_data(m), do: m

  [filter: fields_to_filter] = Application.get_env(:seven, __MODULE__) || [filter: []]

  fields_to_filter
  |> Enum.each(fn f ->
    defp filter(unquote(f), _v), do: {unquote(f), "(filtered)"}
  end)

  defp filter(k, v), do: {k, v}
end
