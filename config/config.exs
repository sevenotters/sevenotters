# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :seven, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:seven, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

config :seven,
  print_commands: false,
  print_events: false,
  # in minutes
  aggregate_lifetime: 3_600

config :seven, Seven.Endpoint,
  endpoints: [
    %{name: "API", cowboy_opts: [port: 4002], route: Seven.Endpoint}
  ]

# See [docs](https://github.com/ericmj/mongodb/blob/master/lib/mongo.ex)
# for flags documentation
config :seven, Seven.Data.Persistence,
  database: "seven_dev",
  hostname: "127.0.0.1",
  port: 27_017

config :seven, Seven.Log, filter: [:password]

config :logger, backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :console, level: :debug

config :logger, :file_log,
  path: "log/seven.log",
  level: :info

config :seven, Seven.Entities,
  entity_app: :seven,
  batches: []

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env()}.exs"
