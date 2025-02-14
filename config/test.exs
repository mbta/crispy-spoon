import Config

# Change aws_credentials so it does not affect testing
config :aws_credentials,
  credential_providers: [],
  fail_if_unavailable: false

config :dotcom, :aws_client, AwsClient.Mock

config :dotcom, :cache, Dotcom.Cache.TestCache

config :dotcom, :httpoison, HTTPoison.Mock

config :dotcom, :cms_api_module, CMS.Api.Static

config :dotcom, :date_time_module, Dotcom.Utils.DateTime.Mock

config :dotcom, :mbta_api_module, MBTA.Api.Mock

config :dotcom, :location_service, LocationService.Mock

config :dotcom, :repo_modules,
  alerts: Alerts.Repo.Mock,
  predictions: Predictions.Repo.Mock,
  route_patterns: RoutePatterns.Repo.Mock,
  routes: Routes.Repo.Mock,
  stops: Stops.Repo.Mock

config :dotcom, :predictions_phoenix_pub_sub, Predictions.Phoenix.PubSub.Mock
config :dotcom, :predictions_pub_sub, Predictions.PubSub.Mock
config :dotcom, :predictions_store, Predictions.Store.Mock

config :dotcom, :redis, Dotcom.Redis.Mock
config :dotcom, :redix, Dotcom.Redix.Mock
config :dotcom, :redix_pub_sub, Dotcom.Redix.PubSub.Mock

config :dotcom, :otp_module, OpenTripPlannerClient.Mock
config :dotcom, :req_module, Req.Mock

config :dotcom, :trip_plan_feedback_cache, Dotcom.Cache.TestCache

# Let test requests get routed through the :secure pipeline
config :dotcom, :secure_pipeline,
  force_ssl: [
    host: nil,
    rewrite_on: [:x_forwarded_proto]
  ]

# Credentials that always show widget and pass backend validation:
config :recaptcha,
  http_client: Recaptcha.Http.MockClient
