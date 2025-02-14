import Config

config :dotcom, :aws_client, AwsClient.Behaviour

config :dotcom, :cms_api_module, CMS.Api

config :dotcom, :content_security_policy_definition, ""

config :dotcom, :date_time_module, Dotcom.Utils.DateTime

config :dotcom, :httpoison, HTTPoison

config :dotcom, :location_service, LocationService

config :dotcom, :mbta_api_module, MBTA.Api

config :dotcom, :otp_module, OpenTripPlannerClient

config :dotcom, :predictions_phoenix_pub_sub, Predictions.Phoenix.PubSub
config :dotcom, :predictions_pub_sub, Predictions.PubSub
config :dotcom, :predictions_store, Predictions.Store

config :dotcom, :redis, Dotcom.Cache.Multilevel.Redis
config :dotcom, :redix, Redix
config :dotcom, :redix_pub_sub, Redix.PubSub

config :dotcom, :repo_modules,
  alerts: Alerts.Repo,
  predictions: Predictions.Repo,
  route_patterns: RoutePatterns.Repo,
  routes: Routes.Repo,
  stops: Stops.Repo

config :dotcom, :req_module, Req

config :dotcom, :service_rollover_time, ~T[03:00:00]

config :dotcom, :timezone, "America/New_York"

tile_server_url =
  if config_env() == :prod,
    do: "https://cdn.mbta.com",
    else: "https://mbta-map-tiles-dev.s3.amazonaws.com"

config :dotcom, tile_server_url: tile_server_url

config :elixir, ansi_enabled: true

config :mbta_metro, custom_icons: ["#{File.cwd!()}/priv/static/icon-svg/*"]

for config_file <- Path.wildcard("config/{deps,dotcom}/*.exs") do
  import_config("../#{config_file}")
end

config :mbta_metro, :map, %{
  center: [-71.0589, 42.3601],
  maxZoom: 18,
  minZoom: 8,
  style: %{
    "version" => 8,
    "sources" => %{
      "raster-tiles" => %{
        "type" => "raster",
        "tiles" => ["#{tile_server_url}/osm_tiles/{z}/{x}/{y}.png"],
        "tileSize" => 256,
        "attribution" =>
          "&copy; <a href=\"https://www.openstreetmap.org/copyright\">OpenStreetMap</a>"
      }
    },
    "layers" => [
      %{
        "id" => "mbta-tiles",
        "type" => "raster",
        "source" => "raster-tiles"
      }
    ]
  },
  zoom: 14
}

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  context_lines: 5

import_config "#{config_env()}.exs"
