# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :algolia, :config,
  app_id: {:system, "ALGOLIA_APP_ID"},
  search: {:system, "ALGOLIA_SEARCH_KEY"},
  write: {:system, "ALGOLIA_WRITE_KEY"}

config :algolia, :repos,
  stops: Stops.Api,
  routes: Routes.Repo

config :algolia, :indexes, [
  Algolia.Stops,
  Algolia.Routes
]

config :algolia, :track_clicks?, false

config :algolia, :index_suffix, ""

config :algolia, :http_pool, :algolia_http_pool

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :algolia, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:algolia, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env()}.exs"
