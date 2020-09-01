defmodule Seven.ProcessSupervisor do
  use DynamicSupervisor

  def start_link(_opts), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_process(handler, process_id, opts) do
    spec = %{id: handler, start: {handler, :start_link, [process_id, opts]}, restart: :transient}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
