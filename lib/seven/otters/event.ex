defmodule Seven.Otters.Event do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct id: nil,
            type: nil,
            counter: nil,
            request_id: nil,
            correlation_id: nil,
            correlation_module: nil,
            date: nil,
            payload: %{}

  @spec create(String.t(), Map.t(), atom) :: Map.t()
  def create(type, payload, correlation_module) do
    struct(
      %__MODULE__{},
      id: Seven.Data.Persistence.new_id(),
      date: DateTime.utc_now() |> DateTime.to_iso8601(),
      type: type,
      correlation_module: correlation_module,
      payload: payload
    )
  end
end
