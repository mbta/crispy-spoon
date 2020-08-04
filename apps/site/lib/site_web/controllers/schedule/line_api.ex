defmodule SiteWeb.ScheduleController.LineApi do
  @moduledoc "Provides JSON endpoints for retrieving line diagram data."
  use SiteWeb, :controller

  alias Alerts.Stop, as: AlertsStop
  alias Routes.Route
  alias Schedules.Repo, as: SchedulesRepo
  alias Site.TransitNearMe
  alias SiteWeb.ScheduleController.Line.DiagramHelpers
  alias SiteWeb.ScheduleController.Line.Helpers, as: LineHelpers
  alias Stops.Repo, as: StopsRepo
  alias Stops.RouteStop
  alias Vehicles.Repo, as: VehiclesRepo
  alias Vehicles.Vehicle

  import SiteWeb.StopController, only: [json_safe_alerts: 2]

  @typep simple_vehicle :: %{
           id: String.t(),
           headsign: String.t() | nil,
           status: String.t(),
           trip_name: String.t() | nil,
           crowding: Vehicle.crowding() | nil
         }

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => route_id, "direction_id" => direction_id}) do
    case LineHelpers.get_route(route_id) do
      {:ok, route} ->
        conn =
          conn
          |> assign(:route, route)
          |> assign(:direction_id, direction_id)
          |> assign_alerts(filter_by_direction?: true)

        line_data =
          get_line_data(route, String.to_integer(direction_id), conn.query_params["variant"])

        json(
          conn,
          Enum.map(line_data, fn stop ->
            update_route_stop_data(stop, conn.assigns.alerts, conn.assigns.date)
          end)
        )

      :not_found ->
        return_invalid_arguments_error(conn)
    end
  end

  @doc """
  Provides predictions and vehicle information for a given route and direction, organized by stop.
  The line diagram polls this endpoint for its real-time data.
  """
  @spec realtime(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def realtime(conn, %{"id" => route_id, "direction_id" => direction_id}) do
    cache_key = {route_id, direction_id, conn.assigns.date}

    payload =
      ConCache.get_or_store(:line_diagram_realtime_cache, cache_key, fn ->
        do_realtime(route_id, direction_id, conn.assigns.date, conn.assigns.date_time)
      end)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, payload)
  end

  defp do_realtime(route_id, direction_id, date, now) do
    headsigns_by_stop =
      TransitNearMe.time_data_for_route_by_stop(
        route_id,
        String.to_integer(direction_id),
        date: date,
        now: now
      )

    vehicles_by_stop =
      route_id
      |> expand_route_id()
      |> Stream.flat_map(&VehiclesRepo.route(&1, direction_id: String.to_integer(direction_id)))
      |> Stream.map(&update_vehicle_with_parent_stop(&1))
      |> Enum.group_by(& &1.stop_id)

    combined_data_by_stop =
      Map.keys(headsigns_by_stop)
      |> Stream.concat(Map.keys(vehicles_by_stop))
      |> Stream.uniq()
      |> Stream.map(fn stop_id ->
        {stop_id,
         %{
           headsigns: Map.get(headsigns_by_stop, stop_id, []),
           vehicles: Map.get(vehicles_by_stop, stop_id, []) |> Enum.map(&simple_vehicle_map(&1))
         }}
      end)
      |> Enum.into(%{})

    Jason.encode!(combined_data_by_stop)
  end

  @spec expand_route_id(Route.id_t()) :: [Route.id_t()]
  defp expand_route_id("Green"), do: GreenLine.branch_ids()
  defp expand_route_id(route_id), do: [route_id]

  @spec get_line_data(Route.t(), LineHelpers.direction_id(), Route.branch_name()) ::
          [DiagramHelpers.stop_with_bubble_info()]
  defp get_line_data(route, direction_id, variant) do
    route
    |> LineHelpers.get_branch_route_stops(direction_id, variant)
    |> DiagramHelpers.build_stop_list(direction_id)
  end

  @spec update_route_stop_data({any, RouteStop.t()}, any, DateTime.t()) :: map()
  def update_route_stop_data({data, %RouteStop{id: stop_id} = map}, alerts, date) do
    %{
      alerts: alerts |> AlertsStop.match(stop_id) |> json_safe_alerts(date),
      route_stop: RouteStop.to_json_safe(map),
      stop_data: Enum.map(data, fn {key, value} -> %{branch: key, type: value} end)
    }
  end

  @spec simple_vehicle_map(Vehicle.t()) :: simple_vehicle
  defp simple_vehicle_map(%Vehicle{id: id, status: status, trip_id: trip_id, crowding: crowding}) do
    case SchedulesRepo.trip(trip_id) do
      nil ->
        %{id: id, status: status}

      %{headsign: headsign, name: name} ->
        %{
          id: id,
          headsign: headsign,
          status: status,
          trip_name: name,
          crowding: crowding
        }
    end
  end

  @spec update_vehicle_with_parent_stop(Vehicle.t()) :: Vehicle.t()
  defp update_vehicle_with_parent_stop(vehicle) do
    case StopsRepo.get_parent(vehicle.stop_id) do
      nil -> vehicle
      parent_stop -> %{vehicle | stop_id: parent_stop.id}
    end
  end
end
