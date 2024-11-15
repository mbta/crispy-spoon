defmodule DotcomWeb.ScheduleController.TimetableController do
  @moduledoc "Handles the Timetable tab for commuter rail routes."

  use DotcomWeb, :controller

  require Logger

  alias DotcomWeb.ScheduleView
  alias Plug.Conn
  alias RoutePatterns.RoutePattern
  alias Routes.Route
  alias Stops.Stop

  @route_patterns_repo Application.compile_env!(:dotcom, :repo_modules)[:route_patterns]
  @stops_repo Application.compile_env!(:dotcom, :repo_modules)[:stops]

  plug(DotcomWeb.Plugs.Route)
  plug(DotcomWeb.Plugs.DateInRating)
  plug(:tab_name)
  plug(:direction_id)
  plug(DotcomWeb.ScheduleController.RoutePdfs)
  plug(DotcomWeb.ScheduleController.Core)
  plug(:do_assign_trip_schedules)
  plug(DotcomWeb.ScheduleController.Offset)
  plug(DotcomWeb.ScheduleController.ScheduleError)
  plug(:channel_id)

  defdelegate direction_id(conn, params),
    to: DotcomWeb.ScheduleController.Defaults,
    as: :assign_direction_id

  def show(conn, _) do
    direction_id = conn.assigns[:direction_id]
    direction_name = conn.assigns.route.direction_names[direction_id]

    {:ok, formatted_date} = Timex.format(conn.assigns.date, "{Mfull} {D}, {YYYY}")

    conn
    |> assign(
      :meta_description,
      "MBTA #{conn.assigns.route.name} Commuter Rail stations and " <>
        "schedules, including timetables, maps, fares, real-time updates, parking and accessibility information, " <>
        "and connections."
    )
    |> assign(:direction_name, direction_name)
    |> assign(:formatted_date, formatted_date)
    |> put_view(ScheduleView)
    |> render("show.html", [])
  end

  # Plug that assigns trip schedule to the connection
  defp do_assign_trip_schedules(conn, _) do
    Util.log_duration(__MODULE__, :assign_trip_schedules, [conn])
  end

  def assign_trip_schedules(
        %{assigns: %{route: route, direction_id: direction_id, date_in_rating?: true}} = conn
      ) do
    timetable_schedules = timetable_schedules(conn)
    vehicle_schedules = vehicle_schedules(conn, timetable_schedules)
    prior_stops = prior_stops(vehicle_schedules)

    %{
      trip_schedules: trip_schedules,
      trip_stops: trip_stops
    } = build_timetable(conn, timetable_schedules)

    header_schedules =
      trip_schedules
      |> Map.values()
      |> header_schedules()

    track_changes = track_changes(trip_schedules, Enum.map(trip_stops, & &1.id))

    header_stops =
      trip_stops
      |> Enum.map(&@stops_repo.get_parent/1)
      |> Enum.with_index()

    conn
    |> assign(:timetable_schedules, timetable_schedules)
    |> assign(:header_schedules, header_schedules)
    |> assign(:header_stops, header_stops)
    |> assign(:trip_schedules, trip_schedules)
    |> assign(:track_changes, track_changes)
    |> assign(:vehicle_schedules, vehicle_schedules)
    |> assign(:prior_stops, prior_stops)
    |> assign(:trip_messages, trip_messages(route, direction_id))
  end

  def assign_trip_schedules(conn) do
    conn
    |> assign(:timetable_schedules, [])
    |> assign(:header_schedules, [])
    |> assign(:vehicle_schedules, [])
    |> assign(:prior_stops, %{})
  end

  @spec track_changes(
          %{required({Schedules.Trip.id_t(), Stop.id_t()}) => Schedules.Schedule.t()},
          [Stop.id_t()]
        ) :: %{
          required({Schedules.Trip.id_t(), Stop.id_t()}) => Stop.t() | nil
        }
  defp track_changes(trip_schedules, canonical_stop_ids) do
    Map.new(trip_schedules, fn {{trip_id, stop_id}, sch} ->
      track_change = track_change_for_schedule(sch, canonical_stop_ids)

      {
        {trip_id, stop_id},
        track_change
      }
    end)
  end

  @spec track_change_for_schedule(
          Schedules.Schedule.t(),
          [Stop.id_t()]
        ) :: Stop.t() | nil
  @doc """
  If the scheduled platform stop is not canonical, then return the stop of that track change.
  """
  def track_change_for_schedule(schedule, canonical_stop_ids, stop_get_fn \\ &@stops_repo.get/1) do
    if has_scheduled_track_change(schedule, canonical_stop_ids) do
      case stop_get_fn.(schedule.platform_stop_id) do
        nil -> nil
        # If there is no platform code for the scheduled platform stop, treat as no track change
        %{platform_code: nil} -> nil
        platform_stop -> platform_stop
      end
    else
      nil
    end
  end

  defp has_scheduled_track_change(schedule, canonical_stop_ids) do
    # if the scheduled stop doesn't match a canonical stop, there has been a track change
    length(canonical_stop_ids) > 0 &&
      schedule.platform_stop_id not in canonical_stop_ids
  end

  # Helper function for obtaining schedule data
  @spec timetable_schedules(Plug.Conn.t()) :: [Schedules.Schedule.t()]
  defp timetable_schedules(%{assigns: %{date: date, route: route, direction_id: direction_id}}) do
    case Schedules.Repo.by_route_ids([route.id], date: date, direction_id: direction_id) do
      {:error, _} ->
        []

      schedules ->
        schedules
        |> Enum.reject(&Schedules.Schedule.no_times?/1)
    end
  end

  @doc """
  Additional text to be included in the timetable.
  We use this for Commuter Rail trips which travel via atypical routes, in
  order to match the PDF schedules. Each rating, this should be checked
  against the new PDFs to ensure it's kept up to date.
  """
  @spec trip_messages(Routes.Route.t(), 0 | 1) :: %{{String.t(), String.t()} => String.t()}
  def trip_messages(%Routes.Route{id: "CR-Franklin"}, 0) do
    ["741", "757", "759", "735"]
    |> Enum.flat_map(&franklin_via_fairmount(&1, 0))
    |> Enum.into(%{})
  end

  def trip_messages(%Routes.Route{id: "CR-Franklin"}, 1) do
    ["740", "752", "728", "758", "732", "760"]
    |> Enum.flat_map(&franklin_via_fairmount(&1, 1))
    |> Enum.into(%{})
  end

  def trip_messages(%Routes.Route{id: "CR-Providence"}, 0) do
    ["893"] |> Enum.flat_map(&franklin_via_fairmount(&1, 0)) |> Enum.into(%{})
  end

  def trip_messages(_, _) do
    %{}
  end

  defp franklin_via_fairmount(train, direction) do
    stops = stops_for_fairmount(direction)

    [
      List.duplicate(train, length(stops)),
      stops,
      ["Via", "Fair-", "mount", "Line", "-"]
    ]
    |> make_via_list()
    |> Enum.concat([{{train}, "Via Fairmount Line"}])
  end

  defp stops_for_fairmount(1) do
    ["place-NEC-2203", "place-forhl", "place-rugg", "place-bbsta"]
  end

  defp stops_for_fairmount(0) do
    ["place-bbsta", "place-rugg", "place-forhl", "place-NEC-2203"]
  end

  def make_via_list(list) do
    list
    |> List.zip()
    |> Enum.map(fn {train, stop, value} -> {{train, stop}, value} end)
  end

  defp tab_name(conn, _), do: assign(conn, :tab, "timetable")

  @doc """
  Organize the route's schedules for timetable format, where schedules are laid
  out horizontally by stop and vertically by trip.

  Trips are derived from the input schedules, but stops are fetched for the
  given route and direction via the route pattern relation. Where possible,
  canonical route patterns are used to determine the ordered list of stops
  visited. This list is augmented further by the input schedules, which may
  introduce additional stops (in the case of a new shuttle route) or removed
  stops (if such stop is skipped entirely).

  Stops from trips from multiple route patterns are consolidated into a single
  list of unique, ordered stops, taking into consideration directional branching
  (e.g. Newburyport/Rockport overlapping for half its route), multi-platform
  stations (i.e. trips using different stop IDs that are actually in the same
  station), station busways (which, like platforms, have distinct stop IDs), and
  shuttle stops (which may or may not be associated with a station).
  """
  @spec build_timetable(Conn.t(), [Schedules.Schedule.t()]) :: %{
          required(:trip_schedules) => %{
            required({Schedules.Trip.id_t(), Stops.Stop.id_t()}) => Schedules.Schedule.t()
          },
          required(:trip_stops) => [Stops.Stop.t()]
        }
  def build_timetable(conn, schedules) do
    trip_schedules = Map.new(schedules, &trip_schedule(&1))
    inbound? = conn.assigns.direction_id == 1

    trip_stops =
      conn.assigns.route.id
      |> @route_patterns_repo.by_route_id(
        direction_id: conn.assigns.direction_id,
        canonical: Routes.Route.type_atom(conn.assigns.route) in [:commuter_rail, :subway]
      )
      |> with_prioritized_pattern()
      |> Enum.map(&@stops_repo.by_trip(&1.representative_trip_id))
      |> handle_ferry_stops(conn.assigns.route.id, inbound?)
      |> Enum.reduce(&merge_stop_lists(&1, &2, inbound?))
      |> remove_unused_stops(schedules)
      |> add_new_stops(schedules, inbound?)

    %{
      trip_schedules:
        trip_schedules
        |> Map.reject(&schedule_from_other_stop?(&1, trip_stops))
        |> remove_single_stop_trips(),
      trip_stops: trip_stops
    }
  end

  # Timetable stops will be ordered based on the route patterns from which they
  # correspond to, but some timetable PDFs are laid out differently than that
  # from the default route pattern sort_order. For these cases, we need to
  # manipulate this by adjusting which route pattern is processed first.
  defp with_prioritized_pattern([%RoutePattern{route_id: "CR-Franklin"} | _] = route_patterns) do
    route_patterns
    |> with_prioritized_pattern("Foxboro")
  end

  defp with_prioritized_pattern([%RoutePattern{route_id: "CR-Providence"} | _] = route_patterns) do
    route_patterns
    |> with_prioritized_pattern("Stoughton")
  end

  defp with_prioritized_pattern(route_patterns), do: route_patterns

  defp with_prioritized_pattern(route_patterns, pattern_name) do
    Enum.sort_by(route_patterns, &String.contains?(&1.name, pattern_name), :desc)
  end

  @ferry_inbound_ids %{
    "Boat-F1" => [
      "Boat-Hingham",
      "Boat-Hull",
      "Boat-George",
      "Boat-Logan",
      "Boat-Rowes",
      "Boat-Long"
    ],
    "Boat-F6" => [
      "Boat-Winthrop",
      "Boat-Quincy",
      "Boat-Logan",
      "Boat-Fan",
      "Boat-Aquarium"
    ]
  }
  @ferry_inbound_keys Map.keys(@ferry_inbound_ids)

  # For ferry routes with many disjoint/overlapping route patterns,
  # concatenating the lists of stops does not produce readable results. Since
  # these routes are short, we can hardcode the order.
  defp handle_ferry_stops(stop_lists, route_id, inbound?)
       when route_id in @ferry_inbound_keys do
    ordered_ids =
      if inbound? do
        @ferry_inbound_ids[route_id]
      else
        Enum.reverse(@ferry_inbound_ids[route_id])
      end

    stops = Enum.flat_map(stop_lists, & &1) |> Enum.uniq()

    [
      Enum.map(ordered_ids, fn id ->
        Enum.find(stops, &(&1.id == id))
      end)
    ]
  end

  defp handle_ferry_stops(stop_lists, _, _), do: stop_lists

  defp schedule_from_other_stop?({{_, stop_id}, _}, stops) do
    !contains_stop?(stops, %Stop{id: stop_id})
  end

  defp remove_single_stop_trips(trip_schedules) do
    single_stop_trip_ids =
      trip_schedules
      |> Enum.frequencies_by(fn {{trip_id, _}, _} -> trip_id end)
      |> Enum.filter(fn {_, count} -> count == 1 end)
      |> Enum.map(fn {trip_id, _} -> trip_id end)

    trip_schedules
    |> Map.reject(fn {{trip_id, _}, _} ->
      trip_id in single_stop_trip_ids
    end)
  end

  @spec merge_stop_lists([Stop.t()], [Stop.t()], boolean()) :: [Stop.t()]
  defp merge_stop_lists(incoming_stops, base_stops, inbound?) do
    if Enum.all?(incoming_stops, &contains_stop?(base_stops, &1)) do
      base_stops
    else
      incoming_stops
      |> Enum.reject(&contains_stop?(base_stops, &1))
      |> do_merge_stop_lists(base_stops, inbound?)
    end
  end

  @spec contains_stop?([Stop.t()], Stop.t()) :: boolean()
  defp contains_stop?(stops, %Stops.Stop{id: id, parent_id: parent_id}) do
    stop_ids =
      stops
      |> Enum.flat_map(&[&1.id, &1.parent_id])
      |> Enum.reject(&is_nil/1)

    id in stop_ids or parent_id in stop_ids
  end

  defp contains_stop?(_stops, _), do: false

  # Some shuttle stops must be placed manually within the existing stops. Each
  # key is a scheduled stop ID from a shuttle, and the corresponding value is
  # the name of the canonical rail stop it should be placed adjacent to in the
  # inbound direction
  @shuttle_overrides %{
    # Lynn busway is near Lynn Interim station
    "14748" => {:after, "Lynn Interim"},
    # Braintree busway
    "38671" => {:after, "Weymouth Landing/East Braintree"},
    # Anderson/Woburn is after Ballardvale on Haverhill line shuttle
    "place-NHRML-0127" => {:after, "Ballardvale"},
    # Lynn station
    "place-ER-0115" => {:after, "Swampscott"},
    # Wonderland station
    "place-wondl" => {:after, "Lynn"},
    # Add Readville (canonically on other routes) back into the Providence timetable
    "place-DB-0095" => {:after, "Route 128"},
    # Add Newton Highlands shuttle stop to Needham timetable
    "place-newtn" => {:before, "Needham Heights"}
  }
  @shuttle_ids Map.keys(@shuttle_overrides)

  @spec do_merge_stop_lists([Stop.t()], [Stop.t()], boolean()) :: [Stop.t()]
  defp do_merge_stop_lists(stops, [], _), do: stops

  defp do_merge_stop_lists(
         [%Stop{id: id} = stop],
         base_stops,
         inbound?
       )
       when id in @shuttle_ids do
    merge_into_stop_list(stop, base_stops, inbound?)
  end

  defp do_merge_stop_lists(stops, base_stops, inbound?) do
    if inbound? do
      stops ++ base_stops
    else
      base_stops ++ stops
    end
  end

  @spec trip_schedule(Schedules.Schedule.t()) ::
          {{Schedules.Trip.id_t() | nil, Stops.Stop.id_t() | nil}, Schedules.Schedule.t()}
  defp trip_schedule(%Schedules.Schedule{trip: trip, stop: stop} = schedule)
       when not is_nil(trip) and not is_nil(stop) do
    {{trip.id, stop.id}, schedule}
  end

  defp trip_schedule(schedule) do
    :ok =
      Logger.warning(
        "module=#{__MODULE__} trip_schedule schedule=#{inspect(schedule)} #{if is_nil(schedule.trip), do: "no_trip"} #{if is_nil(schedule.stop), do: "no_stop"}"
      )

    {{nil, nil}, schedule}
  end

  @spec header_schedules(list) :: list
  defp header_schedules(timetable_schedules) do
    timetable_schedules
    |> Schedules.Sort.sort_by_first_times()
    |> Enum.map(&List.first/1)
  end

  @spec vehicle_schedules(Conn.t(), list) :: map
  def vehicle_schedules(%{assigns: %{date: date}}, timetable_schedules) do
    case Date.compare(date, Util.service_date()) do
      :eq -> do_vehicle_schedules(timetable_schedules)
      _ -> %{}
    end
  end

  def do_vehicle_schedules(timetable_schedules) do
    timetable_schedules
    |> Enum.map(&construct_vehicle_data/1)
    |> Map.new(&{"#{&1.stop_name}-#{&1.trip_id}", &1})
  end

  defp construct_vehicle_data(%Schedules.Schedule{
         stop: nil,
         stop_sequence: s,
         trip: %Schedules.Trip{id: ti, headsign: headsign}
       }) do
    %{stop_sequence: s, stop_name: headsign, trip_id: ti}
  end

  defp construct_vehicle_data(%Schedules.Schedule{
         stop: %Stops.Stop{name: sn},
         stop_sequence: s,
         trip: %Schedules.Trip{id: ti}
       }) do
    %{stop_sequence: s, stop_name: sn, trip_id: ti}
  end

  defp construct_vehicle_data(%Schedules.Schedule{
         route: %Route{description: :rail_replacement_bus},
         stop_sequence: s,
         trip: %Schedules.Trip{id: ti, headsign: headsign}
       }) do
    %{stop_sequence: s, stop_name: headsign, trip_id: ti}
  end

  defp construct_vehicle_data(_) do
    %{stop_sequence: nil, stop_name: nil, trip_id: nil}
  end

  @spec prior_stops(map) :: map
  def prior_stops(vehicle_schedules) do
    vehicle_schedules
    |> Map.values()
    |> Map.new(&{"#{&1.trip_id}-#{&1.stop_sequence}", "#{&1.stop_name}-#{&1.trip_id}"})
  end

  defp remove_unused_stops(all_stops, schedules) do
    timetable_stops = Enum.map(schedules, & &1.stop) |> Enum.uniq()
    Enum.filter(all_stops, &contains_stop?(timetable_stops, &1))
  end

  defp add_new_stops(all_stops, schedules, inbound?) do
    schedules
    |> Enum.map(& &1.stop)
    |> Enum.uniq()
    |> Enum.reject(&contains_stop?(all_stops, &1))
    |> Enum.sort_by(& &1.id)
    |> Enum.reduce(all_stops, &merge_into_stop_list(&1, &2, inbound?))
  end

  defp merge_into_stop_list(new_stop, base_list, inbound?) do
    with {before_or_after, adjacent_name} <- @shuttle_overrides[new_stop.id],
         index when not is_nil(index) <-
           Enum.find_index(base_list, &match?(%Stops.Stop{name: ^adjacent_name}, &1)) do
      position = insertion_position(before_or_after, inbound?, index)
      List.insert_at(base_list, position, new_stop)
    else
      _ ->
        base_list
    end
  end

  # the after/before label is based on the inbound direction, so needs
  # adjustment for the outbound direction
  defp insertion_position(:before, true, index), do: index
  defp insertion_position(:before, false, index), do: index + 1
  defp insertion_position(:after, true, index), do: index + 1
  defp insertion_position(:after, false, index), do: index

  defp channel_id(conn, _) do
    assign(conn, :channel, "vehicles:#{conn.assigns.route.id}:#{conn.assigns.direction_id}")
  end
end
