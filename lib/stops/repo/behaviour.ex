defmodule Stops.Repo.Behaviour do
  @moduledoc """
  Behavior for an API client for fetching stop data
  """
  alias Routes.Route
  alias Schedules.Trip
  alias Stops.Stop

  @callback old_id_to_gtfs_id(Stop.id_t()) :: Stop.id_t() | nil

  @callback get(Stop.id_t()) :: Stop.t() | nil
  @callback get!(Stop.id_t()) :: Stop.t()

  @callback has_parent?(Stop.t() | Stop.id_t() | nil) :: boolean

  @callback get_parent(Stop.t() | Stop.id_t() | nil) :: Stop.t() | nil

  @callback by_route(Route.id_t(), 0 | 1) :: Stop.stops_response()
  @callback by_route(Route.id_t(), 0 | 1, Keyword.t()) :: Stop.stops_response()

  @callback by_routes([Route.id_t()], 0 | 1) :: Stop.stops_response()
  @callback by_routes([Route.id_t()], 0 | 1, Keyword.t()) :: Stop.stops_response()

  @callback by_route_type(Route.type_int()) :: Stop.stops_response()
  @callback by_route_type(Route.type_int(), Keyword.t()) :: Stop.stops_response()

  @callback by_trip(Trip.id_t()) :: Stop.stops_response()

  @callback stop_exists_on_route?(Stop.id_t(), Route.t(), 0 | 1) :: boolean()

  @callback stop_features(Stop.t()) :: [Stop.stop_feature()]
  @callback stop_features(Stop.t(), Keyword.t()) :: [Stop.stop_feature()]
end
