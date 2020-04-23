defmodule Seven.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications

  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    persistence_opts = Application.get_all_env(:seven)[Seven.Data.Persistence] || []

    # Define workers and child supervisors to be supervised
    children = [
      worker(Seven.Data.Persistence.current(), [persistence_opts],
        restart: :permanent,
        id: :persistence
      ),
      worker(Seven.Entities, [], restart: :permanent, id: :entities),
      worker(Seven.EventStore.EventStore, [], restart: :permanent, id: :event_store),
      supervisor(Seven.BusinessSupervisor, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_all, name: Seven.Application.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
