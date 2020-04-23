defmodule Seven.Otters.Event do
  @moduledoc false

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
      date: now(),
      type: type,
      payload: payload
    )
  end

  defp now do
    {:ok, t} = Timex.now() |> Timex.format("{ISO:Extended}")
    t
  end
end
