defmodule Seven.Registry do
  @moduledoc false

  @correlation_id_regex ~r/(?<handler>.+)_(?<id>.+)$/

  @spec get_aggregate(atom, bitstring) :: {:ok, pid}
  def get_aggregate(handler, correlation_value_id) do
    {key, name} = get_key(handler, correlation_value_id)

    case Registry.lookup(:registry, key) do
      [] -> handler.start_link(key, name: name)
      [{pid, _key}] -> {:ok, pid}
      _ -> raise("More values in registry for key #{key}")
    end
  end

  @spec get_process(atom, bitstring) :: {:ok, pid}
  def get_process(handler, correlation_value_id) do
    {key, name} = get_key(handler, correlation_value_id)

    case Registry.lookup(:registry, key) do
      [] -> Seven.ProcessSupervisor.start_process(handler, key, name: name)
      [{pid, _key}] -> {:ok, pid}
      _ -> raise("More values in registry for key #{key}")
    end
  end

  @spec get_process_by_id(bitstring) :: {:ok, pid}
  def get_process_by_id(correlation_id) do
    name = get_name(correlation_id)
    handler = get_handler_from_key(correlation_id)

    case Registry.lookup(:registry, correlation_id) do
      [] -> Seven.ProcessSupervisor.start_process(handler, correlation_id, name: name)
      [{pid, _key}] -> {:ok, pid}
      _ -> raise("More values in registry for key #{correlation_id}")
    end
  end

  @spec is_loaded(atom, bitstring) :: nil | pid
  def is_loaded(handler, correlation_value_id) do
    {key, _name} = get_key(handler, correlation_value_id)

    case Registry.lookup(:registry, key) do
      [] -> nil
      [{pid, _key}] -> pid
      _ -> raise("More values in registry for key #{key}")
    end
  end

  defp get_handler_from_key(key) do
    %{"handler" => handler, "id" => _id} = Regex.named_captures(@correlation_id_regex, key)
    handler |> String.to_existing_atom()
  end

  defp get_correlation_key(handler, correlation_value_id),
    do: Atom.to_string(handler) <> "_" <> correlation_value_id

  defp get_name(key), do: {:via, Registry, {:registry, key}}

  defp get_key(handler, correlation_value_id) do
    key = get_correlation_key(handler, correlation_value_id)
    name = get_name(key)
    {key, name}
  end
end
