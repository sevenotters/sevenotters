defmodule Seven.Utils.ListOfMaps do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @spec update_item(List.t(), (any -> Bool.t()), List.t() | Function.t()) :: List.t()
      def update_item(items, key_func, values) when is_list(values) do
        case items |> Enum.find_index(key_func) do
          nil ->
            Seven.Log.error("#{__MODULE__} is searching for unexisting item; func_key: #{inspect(key_func)}")

            items

          index ->
            new_item = Enum.at(items, index)

            new_item =
              Enum.reduce(values, new_item, fn {k, v}, acc ->
                Map.put(acc, k, v)
              end)

            List.replace_at(items, index, new_item)
        end
      end

      def update_item(items, key_func, func) when is_function(func, 1) do
        case items |> Enum.find_index(key_func) do
          nil ->
            Seven.Log.error("#{__MODULE__} is searching for unexisting item; func_key: #{inspect(key_func)}")

            items

          index ->
            new_item = Enum.at(items, index)
            new_item = func.(new_item)
            List.replace_at(items, index, new_item)
        end
      end

      @spec delete_item(List.t(), (any -> Bool.t())) :: List.t()
      def delete_item(items, key_func), do: Enum.reject(items, key_func)

      @spec update_or_insert(List.t(), (any -> Bool.t()), Map.t(), List.t()) :: List.t()
      def update_or_insert(items, key_func, insert_data, values) do
        case items |> Enum.find_index(key_func) do
          nil ->
            items ++ [insert_data]

          index ->
            new_item = Enum.at(items, index)

            new_item =
              Enum.reduce(values, new_item, fn {k, v}, acc ->
                Map.put(acc, k, v)
              end)

            List.replace_at(items, index, new_item)
        end
      end

      @spec substitute_or_insert(List.t(), (any -> Bool.t()), Map.t()) :: List.t()
      def substitute_or_insert(items, key_func, new_item) do
        case items |> Enum.find_index(key_func) do
          nil ->
            items ++ [new_item]

          index ->
            List.replace_at(items, index, new_item)
        end
      end
    end
  end
end
