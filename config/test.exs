use Mix.Config

config :seven,
  print_commands: false,
  print_events: false

config :seven, Seven.Data.Persistence, database: "seven_test"

config :logger, level: :error
