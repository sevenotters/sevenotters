defmodule Seven.Utils.Tagger do
  @moduledoc false

  defmacro __using__([]) do
    quote do
      Module.register_attribute(__MODULE__, :tag, persist: true)
    end
  end
end
