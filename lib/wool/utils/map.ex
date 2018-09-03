defmodule Seven.Utils.Map do
  @moduledoc false

  defmacro __using__(_opts) do
    quote location: :keep do
      @spec value_or_default(MapList.t(), any, any) :: any
      def value_or_default(map, field, default) when not is_list(field),
        do: Map.get(map, field, default)

      def value_or_default(map, fields, default) when is_list(fields) do
        case Kernel.get_in(map, fields) do
          nil -> default
          v -> v
        end
      end
    end
  end
end
