defmodule Seven.Otters.Command do
  @moduledoc false

  defstruct id: nil,
            type: nil,
            request_id: nil,
            responder_module: nil,
            payload: %{}

  @spec create(String.t(), Map.t()) :: Map.t()
  def create(type, payload) do
    struct(
      %__MODULE__{},
      id: Seven.Data.Persistence.new_id(),
      type: type,
      payload: payload
    )
  end
end
