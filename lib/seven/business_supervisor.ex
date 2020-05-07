defmodule Seven.BusinessSupervisor do
  use Supervisor

  @moduledoc false

  @endpoints Application.get_all_env(:seven)[Seven.Endpoint]

  alias Seven.Log

  # API
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  # Callback
  def init(:ok) do

    endpoints =
      Enum.map(@endpoints[:endpoints] || [], fn e ->
        Log.info("#{e.name} respond to port #{e.cowboy_opts[:port]}")
        Plug.Adapters.Cowboy.child_spec(:http, e.route, [name: e.name], e.cowboy_opts)
      end)

    registry = [supervisor(Registry, [:unique, :registry])]

    opts = [strategy: :one_for_one]
    policies = Seven.Entities.policies() |> additional_workers()
    services = Seven.Entities.services() |> additional_workers()
    processes = Seven.Entities.processes() |> additional_workers()
    projections = Seven.Entities.projections() |> Map.values() |> additional_workers()

    Supervisor.init(
      policies ++ services ++ processes ++ registry ++ projections ++ endpoints,
      opts
    )
  end

  # Privates
  @spec additional_workers(List.t()) :: List.t()
  defp additional_workers(modules),
    do: modules |> Enum.map(fn m -> worker(m, [], restart: :permanent, id: m) end)
end
