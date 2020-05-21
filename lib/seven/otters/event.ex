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

  @spec create(String.t(), Map.t()) :: Map.t()
  def create(type, payload) do
    struct(
      %__MODULE__{},
      id: Seven.Data.Persistence.new_id(),
      date: DateTime.now!("Etc/UTC") |> DateTime.to_iso8601(),
      type: type,
      payload: payload
    )
  end
end
