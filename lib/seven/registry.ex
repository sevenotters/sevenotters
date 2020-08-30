defmodule Seven.Registry do
  @moduledoc false

  @spec get_child(atom, bitstring) :: {:ok, pid}
  def get_child(handler, correlation_value_id) do
    {key, name} = get_key(handler, correlation_value_id)

    case Registry.lookup(:registry, key) do
      [] -> handler.start_link(key, name: name)
      [{pid, _key}] -> {:ok, pid}
      _ -> raise("More values in registry for key #{key}")
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

  defp get_key(handler, correlation_value_id) do
    key = Atom.to_string(handler) <> "_" <> correlation_value_id
    name = {:via, Registry, {:registry, key}}
    {key, name}
  end
end
