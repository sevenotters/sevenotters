defmodule Seven.BusinessSupervisor do
  use Supervisor

  @moduledoc false

  # API
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  # Callback
  def init(:ok) do
    require Logger

    registry = [supervisor(Registry, [:unique, :registry])]

    opts = [strategy: :one_for_one]
    policies = Seven.Entities.policies() |> additional_workers()
    services = Seven.Entities.services() |> additional_workers()
    processes = Seven.Entities.processes() |> additional_workers()
    projections = Seven.Entities.projections() |> Map.values() |> additional_workers()

    Supervisor.init(
      policies ++ services ++ processes ++ registry ++ projections,
      opts
    )
  end

  # Privates
  @spec additional_workers(List.t()) :: List.t()
  defp additional_workers(modules),
    do: modules |> Enum.map(fn m -> worker(m, [], restart: :permanent, id: m) end)
end
