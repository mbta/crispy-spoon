defmodule SiteWeb.ScheduleController.FinderApi do
  @moduledoc """
    API for retrieving journeys for a route, and for
    showing trip details for each journey on demand.

    "Departure" here is analogous to PredictedSchedule.t()
  """
  use SiteWeb, :controller

  alias Predictions.Prediction
  alias Routes.Route
  alias Schedules.{Schedule, Trip}
  alias Site.TransitNearMe
  alias SiteWeb.ControllerHelpers
  alias SiteWeb.ScheduleController.TripInfo, as: Trips
  alias SiteWeb.ScheduleController.VehicleLocations, as: Vehicles

  import SiteWeb.ScheduleController.ScheduleApi, only: [format_time: 1, fares_for_service: 4]

  require Logger

  @type react_keys :: :date | :direction | :is_current
  @type react_strings :: [{react_keys, String.t()}]
  @type converted_values :: {Date.t(), integer, boolean}

  @type enhanced_journey :: %{
          departure: PredictedSchedule.t() | nil,
          arrival: PredictedSchedule.t() | nil,
          trip: Trip.t() | nil,
          realtime: TransitNearMe.time_data() | nil
        }

  # How many seconds a departure is considered recent
  @recent_departure_max_age 600

  # Leverage the JourneyList module to return a simplified set of trips
  @spec journeys(Plug.Conn.t(), map) :: Plug.Conn.t()
  def journeys(conn, %{"stop" => stop_id, "date" => date} = params) do
    {:ok, user_selected_date} = Date.from_iso8601(date)
    {schedules, predictions} = load_from_repos(conn, params)

    # Emulate original Schedules tab journey build logic:
    # The original Schedules tab contained a complete list of trips
    # (JourneyList) (minus detailed stop info) for the date, and then
    # allowed to you drill down into a specific trip (TripInfo) on demand.
    # These structs contained all the information desired in the designs,
    # matching the design spec architecturally better than the existing
    # Schedules-only and Predictions-only configuration for
    # ScheduleFinder.
    today? = params["is_current"] == "true"
    current_time = if today?, do: user_selected_date, else: nil

    journey_list_opts = [
      origin_id: stop_id,
      current_time: current_time
    ]

    journeys =
      schedules
      |> JourneyList.build(predictions, :predictions_then_schedules, true, journey_list_opts)
      |> prepare_journeys_for_json()

    json(conn, journeys)
  end

  # Use alternative JourneyList constructor to only return trips with predictions
  @spec departures(Plug.Conn.t(), map) :: Plug.Conn.t()
  def departures(conn, %{"stop" => stop_id} = params) do
    now = conn.assigns.date_time |> DateTime.to_date() |> Date.to_iso8601()
    params = %{"date" => now, "is_current" => "true"} |> Map.merge(params)

    {schedules, predictions} = load_from_repos(conn, params)

    journeys =
      schedules
      |> JourneyList.build_predictions_only(predictions, stop_id, nil)
      |> Map.get(:journeys, [])
      |> Enum.map(&enhance_journeys/1)
      |> prepare_journeys_for_json()

    json(conn, journeys)
  end

  @spec get_trip_info(Plug.Conn.t(), Trip.id_t(), Route.t(), String.t(), String.t(), String.t()) ::
          Plug.Conn.t()
  def get_trip_info(
        conn,
        trip_id,
        route,
        date,
        direction,
        origin
      ) do
    {service_end_date, direction_id, _} = convert_from_string(date: date, direction: direction)
    params = %{"origin" => origin, "trip" => trip_id}
    opts = Map.get(conn.assigns, :trip_info_functions, [])

    trip_info =
      conn
      |> assign(:date, service_end_date)
      |> assign(:direction_id, direction_id)
      |> assign(:origin, origin)
      |> assign(:route, route)
      |> Map.put(:query_params, params)
      |> Vehicles.call(Vehicles.init([]))
      |> Trips.call(Trips.init(opts))
      |> Map.get(:assigns)
      |> Map.get(:trip_info)

    if trip_info do
      trip_info =
        trip_info
        |> add_computed_fares_to_trip_info(route)
        |> json_safe_trip_info()
        |> update_in([:times], &add_delays/1)
        |> update_in([:times], &simplify_time/1)

      json(conn, trip_info)
    else
      original_query_params = conn.query_params

      _ =
        Logger.warn(
          "trip_info_not_found original_query_params=#{Jason.encode!(original_query_params)}"
        )

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(404, "null")
    end
  end

  # Return a modified %TripInfo{} map by building up the conn.
  # Simulates the :trip_info data generated by the schedules/x/schedule tab
  # We wanted to avoid modifying the existing architecture which is still
  # used by Bus. The existing TripInfo architecture relies on the conn and
  # assigns all data into that. The trip_info assign also has a long list
  # of pre-requisites (things that also need to be assigned in the conn),
  # which cannot easily be accessed directly. Hence the long pipeline of
  # conn operations leading up to getting the trip_info data in the Finder
  # API.
  @spec trip(Plug.Conn.t(), map) :: Plug.Conn.t()
  def trip(conn, %{
        "id" => trip_id,
        "route" => route_id,
        "date" => date,
        "direction" => direction,
        "stop" => origin
      }) do
    schedule_route_id = route_id |> get_route_id(trip_id)

    if schedule_route_id do
      route = Routes.Repo.get(schedule_route_id)
      get_trip_info(conn, trip_id, route, date, direction, origin)
    else
      _ = Logger.warn("route_id_not_found route_id=#{route_id}, trip_id=#{trip_id}")

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(404, "null")
    end
  end

  def trip(conn, _) do
    ControllerHelpers.return_invalid_arguments_error(conn)
  end

  # Use internal API to generate list of relevant schedules and predictions
  @spec load_from_repos(Plug.Conn.t(), map) :: {[Schedule.t()], [Prediction.t()]}
  defp load_from_repos(conn, %{
         "id" => route_id,
         "date" => date,
         "direction" => direction,
         "stop" => stop_id,
         "is_current" => is_current
       }) do
    {service_end_date, direction_id, current_service?} =
      convert_from_string(
        date: date,
        direction: direction,
        is_current: is_current
      )

    route_ids = if(route_id == "Green", do: GreenLine.branch_ids(), else: [route_id])

    # JourneyList orders trips according to their prediction time first (if present),
    # and then by scheduled time. If the selected service is valid for the current day,
    # request schedules using today's date instead of the service end date, so that the
    # schedule date matches the prediction dates, keeping trips in order by time.
    current_date = Util.service_date(conn.assigns.date_time)
    schedule_date = if current_service?, do: current_date, else: service_end_date

    schedule_opts = [date: schedule_date, direction_id: direction_id, stop_ids: [stop_id]]
    schedules_fn = Map.get(conn.assigns, :schedules_fn, &Schedules.Repo.by_route_ids/2)

    schedules =
      case schedules_fn.(route_ids, schedule_opts) do
        {:error, error} ->
          _ =
            Logger.warn(
              "module=#{__MODULE__} Error getting schedules for #{route_ids}: #{inspect(error)}"
            )

          []

        schedules ->
          schedules
      end

    # Don't bother fetching predictions if we're looking at a future/past date.
    # We include predictions in the trip list because current day trips MAY have
    # special, added-in predictions w/o normal schedules attached to them (bus).
    prediction_opts = [
      route: Enum.join(route_ids, ","),
      stop: stop_id,
      direction_id: direction_id
    ]

    predictions_fn = Map.get(conn.assigns, :predictions_fn, &Predictions.Repo.all/1)
    predictions = if current_service?, do: predictions_fn.(prediction_opts), else: []

    {schedules, predictions}
  end

  # Add detailed prediction data to journeys known to have predictions.
  @spec enhance_journeys(Journey.t()) :: map
  defp enhance_journeys(%{departure: departure} = journey) do
    now = Timex.now()

    time_map =
      departure
      |> TransitNearMe.build_time_map(now: now)
      |> recent_departure(departure, now)

    Map.put(journey, :realtime, time_map)
  end

  # Trips which have departed the origin/selected station are normally
  # excluded in upcoming departures since their predictions are nil. In
  # order to include recently departed trips along with upcoming, check
  # a prediction's status and limit recent trips to a certain time range.
  # NOTE: Only works for N/S Station and Back Bay, and predictions will
  # drop off (become nil) anytime during the duration of the trip.
  defp recent_departure(
         {_, details},
         %{schedule: schedule, prediction: %{status: "Departed"} = prediction},
         now
       )
       when not is_nil(schedule) do
    time_elapsed = DateTime.diff(now, schedule.time)

    if time_elapsed <= @recent_departure_max_age do
      Map.put(details, :prediction, %{
        time: details.scheduled_time,
        track: prediction.track,
        status: "Departed"
      })
    else
      details
    end
  end

  defp recent_departure({_, details}, _, _), do: details

  @spec prepare_journeys_for_json(JourneyList.t() | [Journey.t() | enhanced_journey]) :: [map]
  defp prepare_journeys_for_json(%{journeys: journeys}) do
    prepare_journeys_for_json(journeys)
  end

  defp prepare_journeys_for_json(journeys) do
    journeys
    |> Enum.map(&destruct_journey/1)
    |> Enum.filter(&journey_has_valid_departure?/1)
    |> Enum.map(&lift_up_route/1)
    |> Enum.map(&set_departure_time/1)
    |> Enum.map(&json_safe_journey/1)
  end

  @spec journey_has_valid_departure?(Journey.t()) :: boolean
  defp journey_has_valid_departure?(%{departure: departure}),
    do: !PredictedSchedule.empty?(struct(PredictedSchedule, departure))

  defp journey_has_valid_departure?(_), do: true

  # Break down structs in order to use Access functions
  @spec destruct_journey(Journey.t()) :: map
  defp destruct_journey(journey) do
    journey
    |> Map.from_struct()
    |> update_in([:departure], &Map.from_struct/1)
    |> update_in([:departure, :schedule], &maybe_destruct_element/1)
    |> update_in([:departure, :prediction], &maybe_destruct_element/1)
  end

  # Convert non-binary parameter values into expected formats
  @spec convert_from_string(react_strings) :: converted_values
  defp convert_from_string(params) do
    {:ok, date} =
      params
      |> Keyword.get(:date)
      |> Date.from_iso8601()

    direction_id =
      params
      |> Keyword.get(:direction)
      |> String.to_integer()

    current_service? = Keyword.get(params, :is_current, false) === "true"

    {date, direction_id, current_service?}
  end

  # Move a representational %Route{} for this journey up to the top level
  # prior to removing from all child elements (redundant/unused by client)
  # Schedule may be nil, in which case, get the route from Prediction
  @spec lift_up_route(map) :: map
  defp lift_up_route(%{departure: %{schedule: %{route: route}}} = journey) do
    put_route(journey, route)
  end

  defp lift_up_route(%{departure: %{prediction: %{route: route}}} = journey) do
    put_route(journey, route)
  end

  defp put_route(journey, route) do
    Map.put_new(journey, :route, Route.to_json_safe(route))
  end

  # Check for predictions w/o a schedule (added in predictions)
  # If there's a prediction and a schedule, use the schedule time
  defp set_departure_time(%{departure: departure} = journey) do
    departure_time =
      case departure do
        %{schedule: nil, prediction: p} -> p.time
        %{schedule: s, prediction: _} -> s.time
      end

    update_in(journey, [:departure], &Map.put_new(&1, :time, format_time(departure_time)))
  end

  # Removes problematic/unnecessary data from JSON response:
  # - Journeys' nested %Stop{} data is unused by client and contains integer keys
  # - Removes nested %Route{} and %Trip{} data as it is redundant
  # - Drops :arrival key from %Journey{}
  @spec json_safe_journey(map) :: map
  defp json_safe_journey(%{departure: departure} = journey) do
    clean_schedule_and_prediction =
      departure
      |> clean_schedule_or_prediction(:schedule)
      |> clean_schedule_or_prediction(:prediction)
      |> update_in([:schedule], &maybe_nil_schedule_stop/1)
      |> update_in([:prediction], &maybe_remove_prediction_stop/1)

    journey
    |> Map.drop([:arrival])
    |> Map.put(:departure, clean_schedule_and_prediction)
  end

  # Removes problematic/unnecessary data from JSON response:
  # - Drops :route from each schedule/prediction (redundant)
  # - :trip is retained since it's needed to calculate fares
  @spec json_safe_trip_info(TripInfo.t()) :: map
  defp json_safe_trip_info(trip_info) do
    clean_schedules_and_predictions =
      trip_info.times
      |> Enum.map(&Map.from_struct/1)
      |> Enum.map(&clean_schedule_or_prediction(&1, :schedule))
      |> Enum.map(&clean_schedule_or_prediction(&1, :prediction))

    trip_info
    |> Map.from_struct()
    |> put_in([:route_type], trip_info.route.type)
    |> Map.drop([:route, :base_fare])
    |> Map.put(:times, clean_schedules_and_predictions)
  end

  defp clean_schedule_or_prediction(%{prediction: nil} = no_prediction, :prediction) do
    no_prediction
  end

  defp clean_schedule_or_prediction(%{schedule: nil} = no_schedule, :schedule) do
    no_schedule
  end

  defp clean_schedule_or_prediction(schedule_or_prediction, key) do
    update_in(schedule_or_prediction, [key], &Map.drop(&1, [:route]))
  end

  defp add_computed_fares_to_trip_info(trip_info, route) do
    origin = List.first(trip_info.times)
    trip = PredictedSchedule.trip(origin)
    stop = PredictedSchedule.stop(origin)

    fare_params = %{
      trip: trip,
      route: route,
      origin: stop.id,
      destination: trip_info.destination_id
    }

    trip_info
    |> Map.put(:times, Enum.map(trip_info.times, &add_computed_fare(&1, fare_params)))
    |> add_computed_fare(fare_params)
  end

  defp add_computed_fare(%{schedule: %{stop: %{id: id}}} = container, fare_params) do
    with_fare =
      container
      |> Map.get(:schedule)
      |> Map.put(:fare, compute_fare(%{fare_params | destination: id}))

    Map.put(container, :schedule, with_fare)
  end

  defp add_computed_fare(%{prediction: _} = no_fare_for_prediction, _) do
    no_fare_for_prediction
  end

  defp add_computed_fare(container, fare_params) do
    Map.put(container, :fare, compute_fare(fare_params))
  end

  # Given params, generate a fare for a particular trip and/or origin/destination
  defp compute_fare(fare_params) do
    fares_for_service(
      fare_params.route,
      fare_params.trip,
      fare_params.origin,
      fare_params.destination
    )
  end

  def maybe_add_delay(%{prediction: nil} = schedule_and_prediction),
    do: schedule_and_prediction

  def maybe_add_delay(%{prediction: %{time: nil}} = schedule_and_prediction),
    do: schedule_and_prediction

  def maybe_add_delay(%{schedule: nil} = schedule_and_prediction),
    do: schedule_and_prediction

  def maybe_add_delay(%{schedule: %{time: nil}} = schedule_and_prediction),
    do: schedule_and_prediction

  def maybe_add_delay(
        %{schedule: %{time: schedule_time}, prediction: %{time: prediction_time}} =
          schedule_and_prediction
      ) do
    delay = DateTime.diff(prediction_time, schedule_time)
    Map.put_new(schedule_and_prediction, :delay, delay)
  end

  defp add_delays(schedules_and_predictions) do
    Enum.map(schedules_and_predictions, &maybe_add_delay/1)
  end

  # Converts a DateTime to a simple string
  defp simplify_time(schedules_and_predictions) do
    Enum.map(
      schedules_and_predictions,
      fn schedule_and_prediction ->
        schedule_and_prediction
        |> update_in([:schedule], &maybe_format_element_time/1)
        |> update_in([:prediction], &maybe_format_element_time/1)
      end
    )
  end

  # Schedule or Prediction may be nil. If not, convert struct to map.
  @spec maybe_destruct_element(Schedule.t() | Prediction.t() | nil) :: map | nil
  defp maybe_destruct_element(nil), do: nil
  defp maybe_destruct_element(el), do: Map.from_struct(el)

  # Schedule may be nil
  @spec maybe_nil_schedule_stop(map | nil) :: map
  defp maybe_nil_schedule_stop(nil), do: nil
  defp maybe_nil_schedule_stop(schedule), do: Map.put(schedule, :stop, nil)

  # A prediction time is nil for the last stop of a trip.
  # Schedule or Prediction itself may be nil however
  @spec maybe_format_element_time(map | nil) :: map | nil
  defp maybe_format_element_time(nil), do: nil
  defp maybe_format_element_time(%{time: nil} = el), do: el
  defp maybe_format_element_time(%{time: time} = el), do: %{el | time: format_time(time)}

  # Prediction may be nil
  @spec maybe_remove_prediction_stop(map | nil) :: map | nil
  defp maybe_remove_prediction_stop(nil), do: nil
  defp maybe_remove_prediction_stop(p), do: Map.put(p, :stop, nil)

  @spec get_route_id(Route.id_t(), Trip.id_t()) :: Route.id_t() | nil
  defp get_route_id("Green", trip_id) do
    schedule_for_trip =
      trip_id
      |> Schedules.Repo.schedule_for_trip()

    if Enum.empty?(schedule_for_trip) do
      nil
    else
      schedule =
        schedule_for_trip
        |> List.first()

      schedule.route.id
    end
  end

  defp get_route_id(route_id, _trip_id), do: route_id
end
