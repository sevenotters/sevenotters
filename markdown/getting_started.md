# Getting started

How to start with The Seven Otters to create your first CQRS/ES application.
The aim of this documentation is to introduce the Seven Otters to developers who want to become familiar with the project.

## Create and prepare a new project

Create a new project:

```elixir
mix new my_first_cqrses --sup
```

Add `:seven` to project dependencies:

```elixir
defp deps do
[
  {:seven, "~> 0.1"}
]
end
```

Update and compile:

```elixir
mix do deps.get, deps.compile, compile
```

## Clean useless stuff

Delete the following files:

```elixir
my_first_cqrses/lib/my_first_cqrses.ex
my_first_cqrses/test/my_first_cqrses_test.exs
```

## Configure application

Add the following sections to ``my_first_cqrses/config/config.exs``:

```elixir
config :seven, Seven.Entities,
  entity_app: :my_first_cqrses

config :logger, :console,
  format: "$date-$time [$level] $message\n",
  level: :info
```

The first section indicates in which application all entities (aggregates, projections, etc.) are defined.

By default Seven Otters uses in memory (and volatile!) event store: events remain in memory and they are lost ending application.
To use Postgres as permanet persistence, add to your configuration:

```elixir
config :seven,
  persistence: SevenottersPostgres.Storage
```

add `sevenotters_postgres` to project dependencies:

```elixir
defp deps do
[
  ...
  {:sevenotters_postgres, "~> 0.1"}
]
end
```

and configure the connection:

```elixir
config :seven, Seven.Data.Persistence,
  database: "my_first_cqrses",
  hostname: "127.0.0.1",
  port: 27_017
```

To use Elasticsearch, add to your configuration:

```elixir
config :seven,
  persistence: SevenottersElasticsearch.Storage
```

add `sevenotters_elasticsearch` to project dependencies:

```elixir
defp deps do
[
  ...
  {:sevenotters_elasticsearch, "~> 0.1"}
]
end
```

and configure the connection:

```elixir
config :seven, Seven.Data.Persistence,
  url: "http://localhost",
  port: 9_200

config :elastix,
  json_options: [keys: :atoms],
  httpoison_options: [hackney: [pool: :elastix_pool]]
```

## Create your first aggregate and add a command

Create a new folder ``my_first_cqrses/lib/aggregate`` and create a new file ``my_first_cqrses/lib/aggregate/user.ex``.

Substitute the content of file ``my_first_cqrses/lib/aggregate/user.ex`` with the following code:

```elixir
defmodule MyFirstCqrses.Aggregate.User do
  use Seven.Otters.Aggregate, aggregate_field: :user

  defstruct user: nil,
            password: nil

  @register_user_command "RegisterUser"
  @register_user_validation [
    :map,
    fields: [
      user: [:string],
      password: [:string, pattern: ~r/.{8,}/]
    ]
  ]

  @user_registered_event "UserRegistered"

  @moduledoc """
    User aggregate.
    Responds to commands:
    - #{@register_user_command}
    """

  defp init_state, do: %__MODULE__{}

  @spec route(String.t(), any) :: {:routed, Map.y(), atom} | {:invalid, Map.t()}
  def route(@register_user_command, params) do
    cmd = %{
      user: params[:user],
      password: params[:password]
    }

    @register_user_command
    |> Seven.Otters.Command.create(cmd)
    |> validate(@register_user_validation)
  end

  def route(_command, _params), do: :not_routed

  defp pre_handle_command(_command, _state), do: :ok

  @spec handle_command(Map.t(), any) :: {:managed, List.t()}
  defp handle_command(%Seven.Otters.Command{type: @register_user_command} = command, state) do
    event = %{
      user: command.payload.user,
      password: command.payload.password
    }

    {:managed, [create_event(@user_registered_event, %{v1: event})]}
  end

  @spec handle_event(Map.t(), any) :: any
  defp handle_event(%Seven.Otters.Event{type: @user_registered_event} = event, state) do
    %{
      state
      | user: event.payload.v1.user,
        password: event.payload.v1.password
    }
  end

end
```

## Test the command

Create a new test file ``my_first_cqrses/test/user_test.exs``.

Substitute the content of this file with the following code:

```elixir
defmodule UserTest do
  use ExUnit.Case

  test "register a new user" do
    Seven.EventStore.EventStore.subscribe("UserRegistered", self())

    request_id = Seven.Data.Persistence.new_id

    result =
      %Seven.CommandRequest{
        id: request_id,
        command: "RegisterUser",
        sender: __MODULE__,
        params: %{user: "Paul User", password: "my_difficult_password"}
      }
      |> Seven.CommandBus.send_command_request()

    refute result == :not_managed, "Command is not managed by anyone"

    assert_receive %Seven.Otters.Event{type: "UserRegistered", request_id: ^request_id, correlation_module: MyFirstCqrses.Aggregate.User}
  end
end
```

Run the test:

```elixir
mix test
```

## Start your application

Start your new application with:

```elixir
mix run --no-halt
# or
iex -S mix 
```

## Congratulation!

Good job! You have just create your first CQRS/ES application in Elixir.

## Learn more

  * Official website: [https://www.sevenotters.org/](https://www.sevenotters.org/)
  * Docs: [https://hexdocs.pm/seven](https://www.sevenotters.org/)
  * Source: [https://github.com/sevenotters](https://www.sevenotters.org/)

## Feedback, requests, help, anythings else

For now any communication with the Seven Otters project team is by [pull requests](https://github.com/sevenotters/sevenotters/pulls) or at <seven.otters.project@gmail.com>.

If you like the project, any active help (in any form) is absolutly welcome.
