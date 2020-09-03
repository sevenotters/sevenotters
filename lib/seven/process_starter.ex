defmodule Seven.ProcessStarter do
  @moduledoc """
  Booting the application, Seven.ProcessStarter starts all not concluded processes.
  """
  use GenServer

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Init
  def init(_opts) do
    Seven.Data.Persistence.processes_id_by_status("started")
    |> Enum.each(&restart_process/1)

    :ignore
  end

  defp restart_process(process_id) do
    Seven.Log.info("Restaring process #{process_id}")
    {:ok, _pid} = Seven.Registry.get_process_by_id(process_id)
  end
end
