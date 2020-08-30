defmodule Seven.Otters.Command do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct id: nil,
            type: nil,
            request_id: nil,
            process_id: nil,
            responder_module: nil,
            payload: %{}

  defdelegate fetch(term, key), to: Map
  defdelegate get(term, key, default), to: Map
  defdelegate get_and_update(term, key, fun), to: Map

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
