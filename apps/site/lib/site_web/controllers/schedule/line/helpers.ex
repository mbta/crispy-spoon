defmodule SiteWeb.ScheduleController.Line.Helpers do
  @moduledoc """
  Helpers for the line page
  """

  alias RoutePatterns.Repo, as: RoutePatternsRepo
  alias RoutePatterns.RoutePattern
  alias Routes.Repo, as: RoutesRepo
  alias Routes.{Route, Shape}
  alias Schedules.Repo, as: SchedulesRepo
  alias Schedules.Trip
  alias Stops.Repo, as: StopsRepo
  alias Stops.{RouteStop, RouteStops, Stop}

  @type query_param :: String.t() | nil
  @type direction_id :: 0 | 1
  @typep stops_by_route :: %{String.t() => [Stop.t()]}

  @spec get_route(String.t()) :: {:ok, Route.t()} | :not_found
  def get_route(route_id) do
    route = do_get_route(route_id)

    if route != nil do
      {:ok, route}
    else
      :not_found
    end
  end

  @spec do_get_route(String.t()) :: Route.t() | nil
  defp do_get_route("Green") do
    RoutesRepo.green_line()
  end

  defp do_get_route(route_id) do
    RoutesRepo.get(route_id)
  end

  @doc """
  Gets a list of RouteStops representing all of the branches on the route. Routes without branches will always be a
  list with a single RouteStops struct.
  """
  @spec get_branch_route_stops(Route.t(), direction_id()) :: [RouteStops.t()]
  @spec get_branch_route_stops(Route.t(), direction_id(), RoutePattern.id_t() | nil) :: [
          RouteStops.t()
        ]
  def get_branch_route_stops(route, direction_id, route_pattern_id \\ nil)

  def get_branch_route_stops(%Route{id: "Green"}, direction_id, route_pattern_id) do
    GreenLine.branch_ids()
    |> Enum.reduce([], fn route_id, acc ->
      case get_route(route_id) do
        {:ok, route} ->
          [route | acc]

        :not_found ->
          acc
      end
    end)
    |> Enum.map(fn route ->
      route
      |> do_get_branch_route_stops(direction_id, route_pattern_id)
      |> RouteStop.list_from_route_patterns(route, direction_id)
    end)
    |> nil_out_shared_stop_branches()
    |> RouteStops.from_route_stop_groups()
  end

  def get_branch_route_stops(route, direction_id, route_pattern_id) do
    route
    |> do_get_branch_route_stops(direction_id, route_pattern_id)
    |> RouteStop.list_from_route_patterns(route, direction_id)
    |> Enum.chunk_by(& &1.branch)
    |> RouteStops.from_route_stop_groups()
  end

  @spec do_get_branch_route_stops(Route.t(), direction_id(), RoutePattern.id_t() | nil) :: [
          {RoutePattern.t(), [Stop.t()]}
        ]
  defp do_get_branch_route_stops(route, direction_id, route_pattern_id) do
    route.id
    |> get_route_patterns(direction_id, route_pattern_id)
    |> Enum.filter(&(&1.typicality == 1))
    |> Enum.map(&stops_for_route_pattern/1)
  end

  # Gathers all of the shapes for the route. Green Line has to make a call for each branch separately, because of course
  @spec get_route_shapes(Route.id_t()) :: [Shape.t()]
  @spec get_route_shapes(Route.id_t(), direction_id | nil) :: [Shape.t()]
  @spec get_route_shapes(Route.id_t(), direction_id | nil, boolean()) :: [Shape.t()]
  @spec get_route_shapes(Route.id_t(), direction_id | nil, boolean(), keyword()) :: [Shape.t()]
  def get_route_shapes(route_id, direction_id \\ nil, filter_by_priority? \\ true, opts \\ [])

  def get_route_shapes("Green", direction_id, filter_by_priority?, opts) do
    GreenLine.branch_ids()
    |> Enum.join(",")
    |> get_route_shapes(direction_id, filter_by_priority?, opts)
  end

  def get_route_shapes(route_id, direction_id, filter_by_priority?, opts) do
    get_shapes_fn = Keyword.get(opts, :get_shapes_fn, &RoutesRepo.get_shapes/3)
    shapes_opts = if direction_id == nil, do: [], else: [direction_id: direction_id]
    get_shapes_fn.(route_id, shapes_opts, filter_by_priority?)
  end

  @spec get_route_stops(Route.id_t(), direction_id, StopsRepo.stop_by_route()) ::
          stops_by_route()
  def get_route_stops("Green", direction_id, stops_by_route_fn) do
    GreenLine.branch_ids()
    |> Task.async_stream(&do_get_route_stops(&1, direction_id, stops_by_route_fn))
    |> Enum.reduce(%{}, fn {:ok, value}, acc -> Map.merge(acc, value) end)
  end

  def get_route_stops(route_id, direction_id, stops_by_route_fn) do
    do_get_route_stops(route_id, direction_id, stops_by_route_fn)
  end

  @spec do_get_route_stops(Route.id_t(), direction_id, StopsRepo.stop_by_route()) ::
          stops_by_route()
  defp do_get_route_stops(route_id, direction_id, stops_by_route_fn) do
    case stops_by_route_fn.(route_id, direction_id, []) do
      {:error, _} -> %{}
      stops -> %{route_id => stops}
    end
  end

  @spec get_active_shapes([Shape.t()], Route.t(), Shape.id_t()) :: [
          Shape.t()
        ]
  def get_active_shapes(shapes, %Route{type: 3}, shape_id) do
    shapes
    |> get_requested_shape(shape_id)
    |> get_default_shape(shapes)
  end

  def get_active_shapes(_shapes, %Route{id: "Green"}, _shape_id) do
    # not used by the green line code
    []
  end

  def get_active_shapes(shapes, _route, _shape_id), do: shapes

  @spec get_requested_shape([Shape.t()], query_param) :: Shape.t() | nil
  defp get_requested_shape(_shapes, nil), do: nil
  defp get_requested_shape(shapes, shape_id), do: Enum.find(shapes, &(&1.id == shape_id))

  @spec get_default_shape(Shape.t() | nil, [Shape.t()]) :: [Shape.t()]
  defp get_default_shape(nil, [default | _]), do: [default]
  defp get_default_shape(%Shape{} = shape, _shapes), do: [shape]
  defp get_default_shape(_, _), do: []

  @spec active_shape(shapes :: [Shape.t()], route_type :: 0..4) :: Shape.t() | nil
  def active_shape([active | _], 3), do: active
  def active_shape(_shapes, _route_type), do: nil

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

  @spec stops_for_route_pattern(RoutePattern.t()) :: {RoutePattern.t(), [Stop.t()]}
  defp stops_for_route_pattern(route_pattern) do
    stops =
      route_pattern
      |> trip_for_route_pattern()
      |> shape_for_trip()
      |> stops_for_shape()

    {route_pattern, stops}
  end

  @spec trip_for_route_pattern(RoutePattern.t()) :: Trip.t() | nil
  defp trip_for_route_pattern(%RoutePattern{representative_trip_id: representative_trip_id}),
    do: SchedulesRepo.trip(representative_trip_id)

  @spec shape_for_trip(Trip.t() | nil) :: Shape.t() | nil
  defp shape_for_trip(nil), do: nil

  defp shape_for_trip(%Trip{shape_id: shape_id}) do
    shape_id
    |> RoutesRepo.get_shape()
    |> List.first()
  end

  @spec stops_for_shape(Shape.t() | nil) :: [Stop.t()]
  defp stops_for_shape(nil), do: []
  defp stops_for_shape(%Shape{stop_ids: stop_ids}), do: Enum.map(stop_ids, &StopsRepo.get!/1)

  @spec get_route_patterns(Route.id_t(), direction_id(), RoutePattern.id_t() | nil) :: [
          RoutePattern.t()
        ]
  defp get_route_patterns(route_id, direction_id, nil),
    do: RoutePatternsRepo.by_route_id(route_id, direction_id: direction_id)

  defp get_route_patterns(_route_id, _direction_id, route_pattern_id) do
    case RoutePatternsRepo.get(route_pattern_id) do
      %RoutePattern{} = route_pattern ->
        [route_pattern]

      nil ->
        []
    end
  end

  @spec nil_out_shared_stop_branches([[RouteStop.t()]]) :: [[RouteStop.t()]]
  defp nil_out_shared_stop_branches(route_stop_groups) do
    shared_ids = shared_ids(route_stop_groups)

    Enum.map(route_stop_groups, &do_nil_out_shared_stop_branches(&1, shared_ids))
  end

  @spec do_nil_out_shared_stop_branches([RouteStop.t()], MapSet.t(Stop.id_t())) :: [RouteStop.t()]
  defp do_nil_out_shared_stop_branches(route_pattern_group, shared_ids) do
    Enum.map(route_pattern_group, fn route_stop ->
      if MapSet.member?(shared_ids, route_stop.id) do
        %RouteStop{
          route_stop
          | branch: nil
        }
      else
        route_stop
      end
    end)
  end

  @spec shared_ids([[RouteStop.t()]]) :: MapSet.t(Stop.id_t())
  defp shared_ids(route_stop_groups) do
    stop_id_sets =
      route_stop_groups
      |> Enum.map(fn group ->
        group
        |> Enum.map(& &1.id)
        |> MapSet.new()
      end)

    [
      [0, 1],
      [0, 2],
      [0, 3],
      [1, 2],
      [1, 3],
      [2, 3]
    ]
    |> Enum.map(&intersection(&1, stop_id_sets))
    |> Enum.reduce(MapSet.new(), fn set, acc -> MapSet.union(set, acc) end)
  end

  @spec intersection([non_neg_integer()], [MapSet.t()]) :: MapSet.t()
  defp intersection(indices, map_sets),
    do: apply(MapSet, :intersection, Enum.map(indices, &Enum.at(map_sets, &1)))
end
