defmodule SiteWeb.ScheduleController.ScheduleApi do
  @moduledoc """
    API for retrieving schedules by trip for a service defined by date
  """
  use SiteWeb, :controller

  alias Fares.Format
  alias Predictions.Prediction
  alias Routes.Route
  alias Schedules.Repo
  alias Site.{BaseFare}

  import Site.TransitNearMe, only: [build_time_map: 2]
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

    services_by_trip =
      case Routes.Repo.get(route_id).type do
        2 -> Enum.map(services_by_trip, &thread_in_predictions/1)
        _ -> services_by_trip
      end

    ordered_trips = ordered_trips -- Enum.map(no_service_trips, &elem(&1, 0))
    ordered_trips_by_stop = sort_trips_by_stop(ordered_trips, Enum.into(services_by_trip, %{}))
    services_by_trip_with_fare = enhance_services(services_by_trip)

    %{by_trip: services_by_trip_with_fare, trip_order: ordered_trips_by_stop}
  end

  # For each trip, attach stop predictions to the matching schedule stop
  defp thread_in_predictions({trip_id, schedules}) do
    predictions =
      [trip: trip_id]
      |> Predictions.Repo.all()
      |> Enum.map(&simplify_prediction/1)
      |> Enum.reduce(%{}, fn x, acc -> Map.merge(acc, x) end)

    first_schedule = List.first(schedules)

    stop_prediction = %{
      headsign: first_schedule.trip.headsign,
      route: first_schedule.route,
      train_number: first_schedule.trip.name
    }

    updated_schedules =
      Enum.map(schedules, fn schedule ->
        Map.put(
          schedule,
          :prediction,
          Map.put(
            stop_prediction,
            :prediction,
            predictions[schedule.stop.id]
          )
        )
      end)

    {trip_id, updated_schedules}
  end

  @spec simplify_prediction(Prediction.t()) :: map
  defp simplify_prediction(%{stop: %{id: stop_id}} = prediction) do
    predicted_schedule = %PredictedSchedule{schedule: nil, prediction: prediction}
    {_ps, simplified_prediction} = build_time_map(predicted_schedule, now: Util.now())

    %{stop_id => simplified_prediction}
  end

  def prune_schedules_by_stop(schedules, stop_id) do
    Enum.drop_while(schedules, fn schedule -> schedule.stop && schedule.stop.id !== stop_id end)
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

  def sort_trips_by_stop(ordered_trips, services_by_trip) do
    Enum.sort_by(
      ordered_trips,
      fn trip_id ->
        services_by_trip[trip_id]
        |> List.first()
        |> (fn sched -> sched.time end).()
      end,
      &date_sorter/2
    )
  end

  def date_sorter(date1, date2) do
    case DateTime.compare(date1, date2) do
      :lt -> true
      :eq -> true
      :gt -> false
    end
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
        fares_for_service(origin.route, origin.trip, origin.stop.id, &1.stop.id)
      )
    )
  end

  def duration_for_service(schedules) do
    first = List.first(schedules).time
    last = List.last(schedules).time
    %{schedules: schedules, duration: Timex.diff(last, first, :minutes)}
  end

  def format_time(time) do
    hour =
      cond do
        time.hour == 0 -> 12
        time.hour > 12 -> time.hour - 12
        true -> time.hour
      end

    hour_string =
      if hour < 10 do
        "0#{hour}"
      else
        Integer.to_string(hour)
      end

    minute_string =
      if time.minute < 10 do
        "0#{time.minute}"
      else
        Integer.to_string(time.minute)
      end

    meridian_string =
      if time.hour < 12 do
        "AM"
      else
        "PM"
      end

    "#{hour_string}:#{minute_string} #{meridian_string}"
  end

  def formatted_time(%{schedules: schedules, duration: duration}) do
    time_formatted_schedules =
      schedules
      |> Enum.map(&Map.update!(&1, :time, fn time -> format_time(time) end))

    %{schedules: time_formatted_schedules, duration: duration}
  end

  @spec fares_for_service(map, map, String.t(), String.t()) :: map
  def fares_for_service(route, trip, origin, destination) do
    %{
      price: route |> BaseFare.base_fare(trip, origin, destination) |> Format.price(),
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
