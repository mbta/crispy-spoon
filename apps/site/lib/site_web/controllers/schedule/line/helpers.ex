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
      |> RouteStop.list_from_route_patterns(route, direction_id, true)
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
    route_patterns = get_route_patterns(route.id, direction_id, route_pattern_id)

    if route.id == "Boat-F1" do
      # Find route patterns with smallest typicality.
      # Isolate the first pattern (which is the primary pattern)
      [first_route_pattern | _] = filter_by_min_typicality(route_patterns)
      [first_route_pattern]
    else
      # Filter route patterns by typicality == 1
      Enum.filter(route_patterns, &by_typicality(&1, route_pattern_id))
    end
    |> Enum.map(&stops_for_route_pattern/1)
    |> maybe_use_overarching_branch()
  end

  # Before constructing branches, detect whether one of the lists of stops is a
  # superset of the other lists of stops. In that case we can just proceed with
  # the superset stop list for display on the line diagram.
  @spec maybe_use_overarching_branch([
          {RoutePattern.t(), [Stop.t()]}
        ]) :: [
          {RoutePattern.t(), [Stop.t()]}
        ]
  defp maybe_use_overarching_branch(branches) do
    case overarching_branch(branches) do
      nil ->
        branches

      overarching_branch ->
        [overarching_branch]
    end
  end

  # Is there a route pattern whose stops cover all stops on all the given route
  # patterns? If so, return it.
  # For example, this happens on CR-Kingston, where one route pattern terminates
  # at Kingston and another goes one stop further to Plymouth. In that case we
  # want to display the route pattern to Plymouth as it emcompasses more stops
  @spec overarching_branch([
          {RoutePattern.t(), [Stop.t()]}
        ]) :: {RoutePattern.t(), [Stop.t()]} | nil
  defp overarching_branch(route_patterns_with_stops) do
    all_stop_sets =
      route_patterns_with_stops
      |> Enum.map(fn {route_pattern, stops} ->
        stops
        |> maybe_adjust_for_rail_replacement_bus(route_pattern)
      end)
      |> Enum.map(&MapSet.new/1)

    route_patterns_with_stops
    |> Enum.find(&has_all_stops?(&1, all_stop_sets))
  end

  # If these stops are for a rail_replacement_bus, some manual adjustments are
  # needed for the line diagram. The line diagram should show rail stops only
  @spec maybe_adjust_for_rail_replacement_bus([Stop.t()], RoutePattern.t()) :: [Stop.t()]
  defp maybe_adjust_for_rail_replacement_bus(stops, %RoutePatterns.RoutePattern{
         id: "Shuttle-AlewifeLittleton" <> _
       }),
       do: Enum.reject(stops, &(&1.id == "place-alfcl"))

  defp maybe_adjust_for_rail_replacement_bus(stops, _), do: stops

  @spec has_all_stops?({RoutePattern.t(), [Stop.t()]}, [MapSet.t(Stop.t())]) :: boolean
  defp has_all_stops?({_route_pattern, stops}, all_stop_sets) do
    all_stop_sets
    |> Enum.all?(&MapSet.subset?(&1, MapSet.new(stops)))
  end

  # Filters route patterns by the smallest typicality found in the array
  @spec filter_by_min_typicality([RoutePattern.t()]) :: [RoutePattern.t()]
  defp filter_by_min_typicality(route_patterns) do
    route_patterns
    |> Enum.reduce({nil, []}, &reduce_by_min_typicality/2)
    |> elem(1)
    |> Enum.reverse()
  end

  @spec reduce_by_min_typicality(RoutePattern.t(), {integer, [RoutePattern.t()]}) ::
          {integer, [RoutePattern.t()]}
  defp reduce_by_min_typicality(route_pattern, acc) do
    %RoutePattern{typicality: typicality} = route_pattern
    {min_typicality, patterns_array} = acc

    cond do
      typicality < min_typicality -> {typicality, [route_pattern]}
      typicality == min_typicality -> {min_typicality, [route_pattern | patterns_array]}
      true -> acc
    end
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

  @spec get_active_shapes([Shape.t()], Route.t()) :: [Shape.t()]
  # If it's type bus, then return default shape
  def get_active_shapes(shapes, %Route{type: 3}), do: get_default_shape(shapes)
  def get_active_shapes(_shapes, %Route{id: "Green"}), do: []
  def get_active_shapes(shapes, _route), do: shapes

  @spec get_default_shape([Shape.t()]) :: [Shape.t()]
  defp get_default_shape([default | _]), do: [default]
  defp get_default_shape(_), do: []

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
    do:
      RoutePatternsRepo.by_route_id(route_id, direction_id: direction_id)
      |> Enum.filter(&(&1.route_id == route_id))

  defp get_route_patterns(route_id, _direction_id, route_pattern_id) do
    case RoutePatternsRepo.get(route_pattern_id) do
      %RoutePattern{route_id: ^route_id} = route_pattern ->
        [route_pattern]

      nil ->
        []
    end
  end

  @spec by_typicality(RoutePattern.t(), RoutePattern.id_t() | nil) :: boolean()
  def by_typicality(%RoutePattern{typicality: typicality}, nil), do: typicality == 1
  def by_typicality(_, _), do: true

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

    stop_id_sets
    |> length()
    |> combination_pairs()
    |> Enum.map(&intersection(&1, stop_id_sets))
    |> Enum.reduce(MapSet.new(), fn set, acc -> MapSet.union(set, acc) end)
  end

  @spec intersection([non_neg_integer()], [MapSet.t()]) :: MapSet.t()
  defp intersection(indices, map_sets),
    do: apply(MapSet, :intersection, Enum.map(indices, &Enum.at(map_sets, &1)))

  @doc """
  Generates every combination of pairs for the given number of possibilities.

  Public solely for testing.

  iex> SiteWeb.ScheduleController.Line.Helpers.combination_pairs(4)
  [
    [0, 1],
    [0, 2],
    [0, 3],
    [1, 2],
    [1, 3],
    [2, 3]
  ]
  """
  @spec combination_pairs(non_neg_integer()) :: [[non_neg_integer()]]
  def combination_pairs(count) do
    for i <- 0..(count - 2),
        j <- (i + 1)..(count - 1) do
      [i, j]
    end
  end
end
