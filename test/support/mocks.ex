# This file houses definitions for defining Mox mocks.

# External
Mox.defmock(AwsClient.Mock, for: AwsClient.Behaviour)
Mox.defmock(HTTPoison.Mock, for: HTTPoison.Base)
Mox.defmock(Req.Mock, for: Req.Behaviour)

# Internal
Mox.defmock(CMS.Api.Mock, for: CMS.Api.Behaviour)
Mox.defmock(Dotcom.Redis.Mock, for: Dotcom.Redis.Behaviour)
Mox.defmock(Dotcom.Redix.Mock, for: Dotcom.Redix.Behaviour)
Mox.defmock(Dotcom.Redix.PubSub.Mock, for: Dotcom.Redix.PubSub.Behaviour)
Mox.defmock(Dotcom.Utils.DateTime.Mock, for: Dotcom.Utils.DateTime.Behaviour)
Mox.defmock(LocationService.Mock, for: LocationService.Behaviour)
Mox.defmock(MBTA.Api.Mock, for: MBTA.Api.Behaviour)
Mox.defmock(OpenTripPlannerClient.Mock, for: OpenTripPlannerClient.Behaviour)
Mox.defmock(Predictions.Phoenix.PubSub.Mock, for: Phoenix.Channel)
Mox.defmock(Predictions.PubSub.Mock, for: [GenServer, Predictions.PubSub.Behaviour])
Mox.defmock(Predictions.Store.Mock, for: Predictions.Store.Behaviour)

# Repos
Mox.defmock(Alerts.Repo.Mock, for: Alerts.Repo.Behaviour)
Mox.defmock(Predictions.Repo.Mock, for: Predictions.Repo.Behaviour)
Mox.defmock(Routes.Repo.Mock, for: Routes.Repo.Behaviour)
Mox.defmock(RoutePatterns.Repo.Mock, for: RoutePatterns.Repo.Behaviour)
Mox.defmock(Stops.Repo.Mock, for: Stops.Repo.Behaviour)
