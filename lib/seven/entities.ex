defmodule Seven.Entities do
  use GenServer

  @moduledoc false

  @opts (Application.get_all_env(:seven)[__MODULE__] || [entity_app: :seven])

  @spec start_link(List.t()) :: {:ok, pid}
  def start_link(opts \\ []) do

    app =  @opts[:entity_app]

    {:ok, modules} = :application.get_key(app, :modules) || {:ok, []}
    state = %{
      aggregates: extract_entities(modules, :aggregate),
      services: extract_entities(modules, :service),
      processes: extract_entities(modules, :process),
      policies: extract_entities(modules, :policy),
      projections: extract_named_entities(modules, :projection)
    }

    GenServer.start_link(__MODULE__, {:ok, state}, opts ++ [name: __MODULE__])
  end

  def init({:ok, state}) do
    Seven.Log.info("#{__MODULE__} started.")
    {:ok, state}
  end

  def aggregates(), do: GenServer.call(__MODULE__, :aggregates)
  def services(), do: GenServer.call(__MODULE__, :services)
  def processes(), do: GenServer.call(__MODULE__, :processes)
  def policies(), do: GenServer.call(__MODULE__, :policies)
  def projections(), do: GenServer.call(__MODULE__, :projections)

  def handle_call(:aggregates, _from, state), do: {:reply, state.aggregates, state}
  def handle_call(:services, _from, state), do: {:reply, state.services, state}
  def handle_call(:processes, _from, state), do: {:reply, state.processes, state}
  def handle_call(:policies, _from, state), do: {:reply, state.policies, state}
  def handle_call(:projections, _from, state), do: {:reply, state.projections, state}

  defp module_name(m), do: m |> to_string() |> String.split(".") |> List.last |> String.to_atom()

  defp extract_entities(modules, tag) do
    Enum.filter(modules, fn m ->
      m.module_info(:attributes)[:tag] != nil and tag in m.module_info(:attributes)[:tag]
    end)
  end

  defp extract_named_entities(modules, tag) do
    Enum.filter(modules, fn m ->
      m.module_info(:attributes)[:tag] != nil and tag in m.module_info(:attributes)[:tag]
    end)
    |> Enum.reduce(%{}, fn m, acc ->
      Map.put(acc, module_name(m), m)
    end)
  end
end
