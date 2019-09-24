defmodule SiteWeb.ScheduleController.MapApi do
  @moduledoc """
    API for retrieving Map data by route and variant
  """
  use SiteWeb, :controller

  alias Routes.Repo, as: RoutesRepo
  alias Routes.{Route, Shape}
  alias SiteWeb.ScheduleController.Line.Maps
  alias Stops.Repo, as: StopsRepo
  alias Stops.{RouteStops, RouteStop, Stop}

  @type query_param :: String.t() | nil
  @type direction_id :: 0 | 1
  @typep stops_by_route :: %{String.t() => [Stop.t()]}

  def show(conn, %{
        "id" => route_id,
        "direction_id" => direction_id
      }) do
    map_data =
      get_map_data(conn, route_id, String.to_integer(direction_id), %{
        stops_by_route_fn: &StopsRepo.by_route/3
      })

    json(conn, map_data)
  end

  def get_map_data(conn, route_id, direction_id, deps) do
    route = get_route(route_id)
    variant = conn.query_params["variant"]
    route_shapes = get_route_shapes(route.id, direction_id)
    route_stops = get_route_stops(route.id, direction_id, deps.stops_by_route_fn)
    active_shapes = get_active_shapes(route_shapes, route, variant)
    filtered_shapes = filter_route_shapes(route_shapes, active_shapes, route)
    branches = get_branches(filtered_shapes, route_stops, route, direction_id)
    map_stops = Maps.map_stops(branches, {route_shapes, active_shapes}, route.id)

    {_map_img_src, dynamic_map_data} = Maps.map_data(route, map_stops, [], [])
    dynamic_map_data
  end

  def get_route("Green") do
    RoutesRepo.green_line()
  end

  def get_route(route_id) do
    RoutesRepo.get(route_id)
  end

  # Gathers all of the shapes for the route. Green Line has to make a call for each branch separately, because of course
  @spec get_route_shapes(Route.id_t(), direction_id | nil) :: [Shape.t()]
  def get_route_shapes(route_id, direction_id \\ nil)

  def get_route_shapes("Green", direction_id) do
    GreenLine.branch_ids()
    |> Enum.join(",")
    |> get_route_shapes(direction_id)
  end

  def get_route_shapes(route_id, direction_id) do
    opts = if direction_id == nil, do: [], else: [direction_id: direction_id]
    RoutesRepo.get_shapes(route_id, opts)
  end

  @spec get_route_stops(Route.id_t(), direction_id, StopsRepo.stop_by_route()) ::
          stops_by_route
  def get_route_stops("Green", direction_id, stops_by_route_fn) do
    GreenLine.branch_ids()
    |> Task.async_stream(&do_get_route_stops(&1, direction_id, stops_by_route_fn))
    |> Enum.reduce(%{}, fn {:ok, value}, acc -> Map.merge(acc, value) end)
  end

  def get_route_stops(route_id, direction_id, stops_by_route_fn) do
    do_get_route_stops(route_id, direction_id, stops_by_route_fn)
  end

  @spec do_get_route_stops(Route.id_t(), direction_id, StopsRepo.stop_by_route()) ::
          stops_by_route
  defp do_get_route_stops(route_id, direction_id, stops_by_route_fn) do
    case stops_by_route_fn.(route_id, direction_id, []) do
      {:error, _} -> %{}
      stops -> %{route_id => stops}
    end
  end

  @spec get_active_shapes([Shape.t()], Route.t(), Route.branch_name()) :: [
          Shape.t()
        ]
  defp get_active_shapes(shapes, %Route{type: 3}, variant) do
    shapes
    |> get_requested_shape(variant)
    |> get_default_shape(shapes)
  end

  defp get_active_shapes(_shapes, %Route{id: "Green"}, _variant) do
    # not used by the green line code
    []
  end

  defp get_active_shapes(shapes, _route, _variant), do: shapes

  @spec get_requested_shape([Shape.t()], query_param) :: Shape.t() | nil
  defp get_requested_shape(_shapes, nil), do: nil
  defp get_requested_shape(shapes, variant), do: Enum.find(shapes, &(&1.id == variant))

  @spec get_default_shape(Shape.t() | nil, [Shape.t()]) :: [Shape.t()]
  defp get_default_shape(nil, [default | _]), do: [default]
  defp get_default_shape(%Shape{} = shape, _shapes), do: [shape]
  defp get_default_shape(_, _), do: []

  # For bus routes, we only want to show the stops for the active route variant.
  @spec filter_route_shapes([Shape.t()], [Shape.t()], Route.t()) :: [
          Shape.t()
        ]
  def filter_route_shapes(_, [active_shape], %Route{type: 3}), do: [active_shape]
  def filter_route_shapes(all_shapes, _active_shapes, _Route), do: all_shapes

  @doc """
  Gets a list of RouteStops representing all of the branches on the route. Routes without branches will always be a
  list with a single RouteStops struct.
  """
  @spec get_branches([Shape.t()], stops_by_route, Route.t(), direction_id) :: [
          RouteStops.t()
        ]
  def get_branches(_, stops, _, _) when stops == %{}, do: []

  def get_branches(shapes, stops, %Route{id: "Green"}, direction_id) do
    GreenLine.branch_ids()
    |> Enum.map(&get_green_branch(&1, stops[&1], shapes, direction_id))
    |> Enum.reverse()
  end

  def get_branches(shapes, stops, route, direction_id) do
    RouteStops.by_direction(stops[route.id], shapes, route, direction_id)
  end

  @spec get_green_branch(
          GreenLine.branch_name(),
          [Stop.t()],
          [Shape.t()],
          direction_id
        ) :: RouteStops.t()
  defp get_green_branch(branch_id, stops, shapes, direction_id) do
    headsign =
      branch_id
      |> RoutesRepo.get()
      |> Map.get(:direction_destinations)
      |> Map.get(direction_id)

    branch =
      shapes
      |> Enum.reject(&is_nil(&1.name))
      |> Enum.filter(&(&1.name =~ headsign))
      |> get_branches(%{branch_id => stops}, %Route{id: branch_id, type: 0}, direction_id)
      |> List.first()

    %{
      branch
      | branch: branch_id,
        stops: Enum.map(branch.stops, &update_green_branch_stop(&1, branch_id))
    }
  end

  @spec update_green_branch_stop(RouteStop.t(), GreenLine.branch_name()) :: RouteStop.t()
  defp update_green_branch_stop(stop, branch_id) do
    # Green line shapes use the headway as their name, so each RouteStop comes back from the repo with their
    # branch set to "Heath St." etc. We change the stop's branch name to nil if the stop is shared, or to the branch
    # id if it's not shared.
    GreenLine.shared_stops()
    |> Enum.member?(stop.id)
    |> do_update_green_branch_stop(stop, branch_id)
  end

  @spec do_update_green_branch_stop(boolean, RouteStop.t(), Route.branch_name()) :: RouteStop.t()
  defp do_update_green_branch_stop(true, stop, _branch_id), do: %{stop | branch: nil}
  defp do_update_green_branch_stop(false, stop, branch_id), do: %{stop | branch: branch_id}
end
