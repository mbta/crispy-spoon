defmodule SiteWeb.ScheduleController.ScheduleApi do
  @moduledoc """
    API for retrieving schedules by trip for a service defined by date
  """
  use SiteWeb, :controller

  alias Fares.Format
  alias Routes.Route
  alias Schedules.Repo
  alias Site.{BaseFare}
  import SiteWeb.ViewHelpers, only: [cms_static_page_path: 2]

  def show(conn, %{
        "id" => route_id,
        "date" => date,
        "direction_id" => direction_id,
        "stop_id" => stop_id
      }) do
    {:ok, date} = Date.from_iso8601(date)
    schedule_data = get_schedules(route_id, date, direction_id, stop_id)

    json(conn, schedule_data)
  end

  @spec get_schedules(String.t(), Date.t(), String.t(), String.t()) :: %{
          by_trip: map,
          trip_order: [String.t()]
        }
  def get_schedules(route_id, date, direction_id, stop_id) do
    services =
      [route_id]
      |> Repo.by_route_ids(date: date, direction_id: direction_id)
      |> Enum.map(&Map.update!(&1, :route, fn route -> Route.to_json_safe(route) end))

    ordered_trips = services |> Enum.map(& &1.trip.id) |> Enum.uniq()

    {no_service_trips, services_by_trip} =
      services
      |> Enum.group_by(& &1.trip.id)
      |> Enum.map(fn {trip_id, schedules} ->
        {trip_id, prune_schedules_by_stop(schedules, stop_id)}
      end)
      |> Enum.split_with(fn {_trip_id, schedules} ->
        Enum.empty?(schedules) || length(schedules) == 1
      end)

    ordered_trips = ordered_trips -- Enum.map(no_service_trips, &elem(&1, 0))
    services_by_trip_with_fare = enhance_services(services_by_trip)

    %{by_trip: services_by_trip_with_fare, trip_order: ordered_trips}
  end

  def prune_schedules_by_stop(schedules, stop_id) do
    Enum.drop_while(schedules, fn schedule -> schedule.stop.id !== stop_id end)
  end

  def enhance_services([]), do: []

  def enhance_services(services_by_trip) do
    services_by_trip
    |> Stream.map(fn {trip_id, service} -> {trip_id, fares_for_service(service)} end)
    |> Stream.map(fn {trip_id, service} -> {trip_id, duration_for_service(service)} end)
    |> Stream.map(fn {trip_id, service} -> {trip_id, formatted_time(service)} end)
    |> Stream.map(fn {trip_id, service} -> {trip_id, route_pattern(service)} end)
    |> Enum.into(%{})
  end

  def route_pattern(%{schedules: [first_schedule | _]} = service) do
    Map.put(service, "route_pattern_id", first_schedule.trip.route_pattern_id)
  end

  def fares_for_service(schedules) do
    origin = List.first(schedules)

    schedules
    |> Enum.map(
      &Map.merge(
        &1,
        fares_for_service(origin.route, origin.stop.id, &1.stop.id)
      )
    )
  end

  def duration_for_service(schedules) do
    first = List.first(schedules).time
    last = List.last(schedules).time
    %{schedules: schedules, duration: Timex.diff(last, first, :minutes)}
  end

  def formatted_time(%{schedules: schedules, duration: duration}) do
    time_formatted_schedules =
      schedules
      |> Enum.map(&Map.update!(&1, :time, fn time -> Timex.format!(time, "{0h12}:{m} {AM}") end))

    %{schedules: time_formatted_schedules, duration: duration}
  end

  @spec fares_for_service(map, String.t(), String.t()) :: map
  def fares_for_service(route, origin, destination) do
    %{
      price: route |> BaseFare.base_fare(origin, destination) |> Format.price(),
      fare_link:
        fare_link(
          Route.type_atom(route.type),
          origin,
          destination
        )
    }
  end

  def fare_link(:bus, _origin, _destination) do
    cms_static_page_path(SiteWeb.Endpoint, "/fares/bus-fares")
  end

  def fare_link(:subway, _origin, _destination) do
    cms_static_page_path(SiteWeb.Endpoint, "/fares/subway-fares")
  end

  def fare_link(:commuter_rail, origin, destination) do
    fare_path(SiteWeb.Endpoint, :show, :commuter_rail, %{
      origin: origin,
      destination: destination
    })
  end

  def fare_link(:ferry, origin, destination) do
    fare_path(SiteWeb.Endpoint, :show, :ferry, %{
      origin: origin,
      destination: destination
    })
  end
end
