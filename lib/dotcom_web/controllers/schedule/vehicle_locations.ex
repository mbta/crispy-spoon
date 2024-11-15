defmodule DotcomWeb.ScheduleController.VehicleLocations do
  @moduledoc """
  Assigns vehicle locations corresponding to the already-assigned schedules, if they exist.
  """

  require Logger

  import Plug.Conn, only: [assign: 3]

  alias Stops.Stop

  @routes_repo Application.compile_env!(:dotcom, :repo_modules)[:routes]
  @stops_repo Application.compile_env!(:dotcom, :repo_modules)[:stops]

  @default_opts [
    location_fn: &Vehicles.Repo.route/2,
    schedule_for_trip_fn: &Schedules.Repo.schedule_for_trip/2
  ]

  @type t :: %{{String.t(), String.t()} => Vehicles.Vehicle.t()}

  def init(opts) do
    Keyword.merge(@default_opts, opts)
  end

  def call(conn, opts) do
    Util.log_duration(__MODULE__, :do_call, [conn, opts])
  end

  def do_call(conn, opts) do
    locations =
      if should_fetch_vehicles?(conn) do
        find_all_locations(conn, opts)
      else
        %{}
      end

    assign(conn, :vehicle_locations, locations)
  end

  @spec active_stop(t, String.t()) :: String.t()
  def active_stop(vehicle_locations, trip_id) do
    vehicle_locations
    |> Map.keys()
    |> Enum.find(fn stop_tuple -> elem(stop_tuple, 0) == trip_id end)
    |> stop_name_from_tuple()
  end

  @spec stop_name_from_tuple({String.t(), String.t() | nil} | nil) :: String.t()
  defp stop_name_from_tuple(nil), do: ""
  defp stop_name_from_tuple({_trip_id, nil}), do: ""
  defp stop_name_from_tuple({_trip_id, stop_id}), do: stop_name(stop_id)

  @spec stop_name(String.t()) :: String.t()
  defp stop_name(<<stop_id::binary>>) do
    stop = @stops_repo.get_parent(stop_id)

    if stop do
      stop.name
    else
      ""
    end
  end

  # don't fetch vehicles for non-commuter rail without an origin.  otherwise
  # make sure the date is today.
  defp should_fetch_vehicles?(%{assigns: %{route: %{type: not_commuter_rail}, origin: nil}})
       when not_commuter_rail != 2 do
    false
  end

  defp should_fetch_vehicles?(conn) do
    conn.assigns.date == Util.service_date(conn.assigns.date_time)
  end

  @spec find_all_locations(Plug.Conn.t(), %{}) :: __MODULE__.t()
  defp find_all_locations(
         %Plug.Conn{
           assigns: %{route: %Routes.Route{id: "Green"}}
         } = conn,
         opts
       ) do
    GreenLine.branch_ids()
    |> Enum.flat_map(fn route_id ->
      find_locations(
        %Plug.Conn{conn | assigns: %{conn.assigns | route: @routes_repo.get(route_id)}},
        opts
      )
    end)
    |> Enum.into(%{})
  end

  defp find_all_locations(conn, opts), do: find_locations(conn, opts)

  @spec find_locations(Plug.Conn.t(), %{}) :: __MODULE__.t()
  defp find_locations(
         %Plug.Conn{
           assigns: %{route: route, direction_id: direction_id, date: date}
         },
         opts
       )
       when not is_nil(route) do
    schedule_for_trip_fn = opts[:schedule_for_trip_fn]

    for vehicle <- opts[:location_fn].(route.id, direction_id: direction_id), into: %{} do
      key = location_key(vehicle, date, schedule_for_trip_fn)
      {key, vehicle}
    end
  end

  defp find_locations(_, _), do: %{}

  @spec location_key(Vehicles.Vehicle.t(), Date.t(), any) :: {String.t() | nil, String.t() | nil}
  defp location_key(%Vehicles.Vehicle{status: :in_transit} = vehicle, date, schedule_for_trip_fn)
       when is_function(schedule_for_trip_fn, 2) do
    schedules = vehicle.trip_id |> schedule_for_trip_fn.(date: date) |> parse_schedules_for_trip()

    if previous_station = find_previous_station(schedules, vehicle.stop_id) do
      {vehicle.trip_id, previous_station.id}
    else
      location_key(vehicle, date, :default)
    end
  end

  defp location_key(%Vehicles.Vehicle{} = vehicle, _date, _schedule_for_trip_fn) do
    {vehicle.trip_id, vehicle.stop_id}
  end

  @spec parse_schedules_for_trip({:error, any} | [Schedules.Schedule.t()]) :: [
          Schedules.Schedule.t()
        ]
  defp parse_schedules_for_trip({:error, reason}) do
    Logger.error("parse_schedules_for_trip: #{inspect(reason)}")

    []
  end

  defp parse_schedules_for_trip(schedules), do: schedules

  defp find_previous_station([], _stop_id), do: nil
  defp find_previous_station([_], _stop_id), do: nil

  defp find_previous_station(
         [previous_stop_schedule, %Schedules.Schedule{stop: %Stop{id: stop_id}} | _rest],
         stop_id
       ) do
    previous_stop_schedule.stop
  end

  defp find_previous_station([_previous, stop_schedule | rest], stop_id) do
    find_previous_station([stop_schedule | rest], stop_id)
  end
end
