defmodule Seven.BusinessSupervisor do
  use Supervisor

  @moduledoc false

  # API
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  # Callback
  def init(:ok) do
    registry = [supervisor(Registry, [:unique, :registry])]

    process_supervisor = [
      %{
        id: Seven.ProcessSupervisor,
        start: {Seven.ProcessSupervisor, :start_link, [[]]}
      }
    ]

    process_starter = [worker(Seven.ProcessStarter, [], restart: :permanent, id: Seven.ProcessStarter)]

    policies = Seven.Entities.policies() |> additional_workers()
    services = Seven.Entities.services() |> additional_workers()
    projections = Seven.Entities.projections() |> Map.values() |> additional_workers()

    Supervisor.init(
      policies ++ services ++ registry ++ projections ++ process_supervisor ++ process_starter,
      strategy: :one_for_one
    )
  end

  # Privates
  @spec additional_workers(List.t()) :: List.t()
  defp additional_workers(modules),
    do: modules |> Enum.map(fn m -> worker(m, [], restart: :permanent, id: m) end)
end
