defmodule Stops.RouteStop do
  @moduledoc """
  A helper module for generating some contextual information about stops on a route. RouteStops contain
  the following information:
  ```
    # RouteStop info for South Station on the Red Line (direction_id: 0)
    %Stops.RouteStop{
      id: "place-sstat",                                  # The id that the stop is typically identified by (i.e. the parent stop's id)
      name: "South Station"                               # Stop's display name
      zone: "1A"                                          # Commuter rail zone (will be nil if stop doesn't have CR routes)
      route: %Route{id: "Red"...}                         # The full Route for the parent route
      branch: nil                                         # Name of the branch that this stop is on for this route. will be nil unless the stop is actually on a branch.
      station_info: %Stop{id: "place-sstat"...}           # Full Stops.Stop struct for the parent stop.

      stop_features: [:commuter_rail, :bus, :accessible]  # List of atoms representing the icons that should be displayed for this stop.
      is_terminus?: false                                 # Whether this is either the first or last stop on the route.
    }
  ```

  """
  alias Routes.{Route, Shape}
  alias RoutePatterns.RoutePattern
  alias Stops.{Repo, Stop}

  @type branch_name_t :: String.t() | nil
  @type direction_id_t :: 0 | 1

  @type t :: %__MODULE__{
          id: Stop.id_t(),
          name: String.t(),
          zone: String.t() | {:error, :not_fetched},
          branch: branch_name_t,
          station_info: Stop.t(),
          route: Route.t() | nil,
          connections: [Route.t()] | {:error, :not_fetched},
          stop_features: [Repo.stop_feature()] | {:error, :not_fetched},
          is_terminus?: boolean,
          is_beginning?: boolean,
          closed_stop_info: Stop.ClosedStopInfo.t() | nil
        }

  defstruct [
    :id,
    :name,
    :branch,
    :station_info,
    :route,
    connections: {:error, :not_fetched},
    zone: {:error, :not_fetched},
    stop_features: {:error, :not_fetched},
    is_terminus?: false,
    is_beginning?: false,
    closed_stop_info: nil
  ]

  alias __MODULE__, as: RouteStop

  def to_json_safe(%RouteStop{connections: connections, route: route} = map) do
    %{
      map
      | connections: Enum.map(connections, &Route.to_json_safe/1),
        route: Route.to_json_safe(route)
    }
  end

  @doc """
  Given a list of route patterns with stops and a route, generates a list of RouteStops representing all stops on that route. If the route has branches, the branched stops appear grouped together in order as part of the list.
  """
  @spec list_from_route_patterns(
          [{RoutePattern.t(), [Stop.t()]}],
          Route.t(),
          direction_id_t(),
          boolean
        ) ::
          [t()]
  def list_from_route_patterns(
        route_patterns_with_stops,
        route,
        direction_id,
        use_route_id_for_branch_name? \\ false
      )

  def list_from_route_patterns([], _route, _direction_id, _use_route_id?), do: []

  def list_from_route_patterns(
        [route_pattern_with_stops],
        route,
        direction_id,
        use_route_id_for_branch_name?
      ) do
    # If there is only one route pattern, we know that we won't need to deal with merging branches so we just return whatever the list of stops is without calling &merge_branch_list/2.
    do_list_from_route_pattern(
      route_pattern_with_stops,
      route,
      direction_id,
      use_route_id_for_branch_name?
    )
  end

  def list_from_route_patterns(
        route_patterns_with_stops,
        route,
        direction_id,
        use_route_id_for_branch_name?
      ) do
    route_patterns_with_stops
    |> Enum.map(
      &do_list_from_route_pattern(&1, route, direction_id, use_route_id_for_branch_name?)
    )
    |> maybe_stitch_chunks()
    |> merge_branch_list(direction_id)
    |> maybe_correct_for_lechmere_shuttle()
  end

  # Special-case the Lechmere shuttle
  @spec maybe_correct_for_lechmere_shuttle([t()]) :: [t()]
  defp maybe_correct_for_lechmere_shuttle([
         %__MODULE__{id: "place-lech"} = lechmere,
         %__MODULE__{} = second,
         %__MODULE__{id: "place-north"} = north
         | rest
       ]) do
    [
      lechmere,
      %__MODULE__{
        second
        | is_terminus?: false,
          is_beginning?: false
      },
      %__MODULE__{
        north
        | is_terminus?: false,
          is_beginning?: false
      }
    ] ++ rest
  end

  defp maybe_correct_for_lechmere_shuttle(route_stops) do
    if List.last(route_stops).id == "place-lech" do
      route_stops
      |> Enum.reverse()
      |> maybe_correct_for_lechmere_shuttle()
      |> Enum.reverse()
    else
      route_stops
    end
  end

  @lechmere_shuttle_route_pattern_ids ["602-1-0", "602-1-1"]
  @spec do_list_from_route_pattern(
          {RoutePattern.t(), [Stop.t()]},
          Route.t(),
          direction_id_t(),
          boolean()
        ) :: [t()]
  defp do_list_from_route_pattern(
         {route_pattern, stops},
         route,
         direction_id,
         use_route_id_for_branch_name?
       ) do
    if String.starts_with?(route.id, "Green") and
         route_pattern.id in @lechmere_shuttle_route_pattern_ids do
      # Special-case the Lechmere shuttle
      stops
      # Filter out the bus stop at North Station
      |> Enum.reject(fn %Stop{id: id} -> id == "21458" end)
      |> Util.EnumHelpers.with_first_last()
      |> Enum.with_index()
      |> Enum.map(fn {{stop, first_or_last?}, idx} ->
        branch = shuttle_branch_name(route, direction_id, use_route_id_for_branch_name?)
        first? = idx == 0
        last? = first_or_last? and idx > 0

        stop
        |> build_route_stop(route, branch: branch, first?: first?, last?: last?)
        |> fetch_zone()
        |> fetch_connections()
        |> fetch_stop_features()
      end)
    else
      stops
      |> Util.EnumHelpers.with_first_last()
      |> Enum.with_index()
      |> Enum.map(fn {{stop, first_or_last?}, idx} ->
        branch = branch_name(route_pattern, use_route_id_for_branch_name?)
        first? = idx == 0
        last? = first_or_last? and idx > 0

        stop
        |> build_route_stop(route, branch: branch, first?: first?, last?: last?)
        |> fetch_zone()
        |> fetch_connections()
        |> fetch_stop_features()
      end)
    end
  end

  @spec branch_name(RoutePattern.t(), boolean()) :: String.t()
  defp branch_name(%RoutePattern{route_id: route_id}, true), do: route_id
  defp branch_name(%RoutePattern{name: name}, false), do: name

  @spec shuttle_branch_name(Route.t(), direction_id_t(), boolean()) :: String.t()
  defp shuttle_branch_name(_, _, true), do: nil
  defp shuttle_branch_name(%Route{id: "Green"}, _, false), do: "Green-E"
  defp shuttle_branch_name(%Route{id: "Green-E"}, 0, false), do: "North Station - Heath Street"
  defp shuttle_branch_name(%Route{id: "Green-E"}, 1, false), do: "Heath Street - North Station"

  @doc """
  Given a route and a list of that route's shapes, generates a list of RouteStops representing all stops on that route. If the route has branches,
  the branched stops appear grouped together in order as part of the list.
  """
  @spec list_from_shapes([Shape.t()], [Stop.t()], Route.t(), direction_id_t) ::
          [RouteStop.t()]
  # Can't build route stops if there are no stops or shapes
  def list_from_shapes([], [], _route, _direction_id), do: []

  def list_from_shapes([], [%Stop{} | _] = stops, route, _direction_id) do
    # if the repo doesn't have any shapes, just fake one since we only need the name and stop_ids.

    stops
    |> List.last()
    |> Map.get(:id)
    |> do_list_from_shapes(Enum.map(stops, & &1.id), stops, route)
  end

  def list_from_shapes(
        [%Shape{} = shape],
        [%Stop{} | _] = stops,
        route,
        _direction_id
      ) do
    # If there is only one route shape, we know that we won't need to deal with merging branches so
    # we just return whatever the list of stops is without calling &merge_branch_list/2.
    do_list_from_shapes(shape.name, shape.stop_ids, stops, route)
  end

  def list_from_shapes(
        [%Shape{} = shape | _],
        stops,
        %Route{type: 4} = route,
        _direction_id
      ) do
    # for the ferry, for now, just return a single branch
    do_list_from_shapes(shape.name, Enum.map(stops, & &1.id), stops, route)
  end

  def list_from_shapes(shapes, stops, %Route{id: "CR-Fairmount"} = route, 0) do
    mainline = Enum.find(shapes, &(&1.name == "South Station - Readville via Fairmount"))
    foxboro_extension = Enum.find(shapes, &(&1.name == "South Station - Foxboro via Fairmount"))

    distinct_stop_ids =
      if foxboro_extension do
        mainline.stop_ids |> Enum.concat(foxboro_extension.stop_ids) |> Enum.uniq()
      else
        mainline.stop_ids
      end

    [do_list_from_shapes(mainline.name, distinct_stop_ids, stops, route)]
    |> merge_branch_list(0)
  end

  def list_from_shapes(shapes, stops, %Route{id: "CR-Fairmount"} = route, 1) do
    mainline = Enum.find(shapes, &(&1.name == "Readville - South Station via Fairmount"))

    foxboro_extension =
      Enum.find(shapes, &(&1.name == "Forge Park/495 - South Station via Fairmount"))

    distinct_stop_ids =
      if foxboro_extension do
        ["place-FS-0049" | foxboro_extension.stop_ids]
        |> Enum.concat(mainline.stop_ids)
        |> Enum.uniq()
      else
        mainline.stop_ids
      end

    [do_list_from_shapes(foxboro_extension.name, distinct_stop_ids, stops, route)]
    |> merge_branch_list(1)
  end

  def list_from_shapes(
        shapes,
        stops,
        %Route{id: "CR-Franklin"} = route,
        0
      ) do
    shapes
    |> Enum.reject(&(&1.name == "South Station - Foxboro via Fairmount"))
    |> Enum.map(&do_list_from_shapes(&1.name, &1.stop_ids, stops, route))
    |> merge_branch_list(0)
  end

  def list_from_shapes(
        shapes,
        stops,
        %Route{id: "CR-Franklin"} = route,
        1
      ) do
    # We need to prefer the shorter "trunk" here when merging the branch list so the trunk stops
    # don't end up being the ones from the Fairmount line
    shapes
    |> Enum.reject(&(&1.name == "Forge Park/495 - South Station via Fairmount"))
    |> Enum.map(&do_list_from_shapes(&1.name, &1.stop_ids, stops, route))
    |> merge_branch_list(1, true)
  end

  def list_from_shapes(shapes, stops, route, direction_id) do
    shapes
    |> Enum.map(&do_list_from_shapes(&1.name, &1.stop_ids, stops, route))
    |> merge_branch_list(direction_id)
  end

  @spec do_list_from_shapes(String.t(), [Stop.id_t()], [Stop.t()], Route.t()) ::
          [RouteStop.t()]
  defp do_list_from_shapes(shape_name, stop_ids, [%Stop{} | _] = stops, route) do
    stops = Map.new(stops, &{&1.id, &1})

    stop_ids
    |> Enum.flat_map(fn stop_id ->
      parent_stop_id =
        stop_id
        |> Repo.get_parent()
        |> Map.fetch!(:id)

      case Map.fetch(stops, parent_stop_id) do
        {:ok, stop} -> [stop]
        :error -> []
      end
    end)
    |> Util.EnumHelpers.with_first_last()
    |> Enum.with_index()
    |> Enum.map(fn {{stop, first_or_last?}, idx} ->
      first? = idx == 0
      last? = first_or_last? and idx > 0
      build_route_stop(stop, route, first?: first?, last?: last?, branch: shape_name)
    end)
  end

  defp do_list_from_shapes(_name, _stop_ids, _stops, _route) do
    []
  end

  @doc """
  Builds a RouteStop from information about a stop.
  """
  @spec build_route_stop(Stop.t(), Route.t(), Keyword.t()) :: RouteStop.t()
  def build_route_stop(%Stop{} = stop, route, opts \\ []) do
    branch = Keyword.get(opts, :branch)
    first? = Keyword.get(opts, :first?) == true
    last? = Keyword.get(opts, :last?) == true

    %RouteStop{
      id: stop.id,
      name: stop.name,
      station_info: stop,
      route: route,
      branch: branch,
      is_terminus?: first? or last?,
      is_beginning?: first?
    }
  end

  @spec fetch_zone(t) :: t
  def fetch_zone(%__MODULE__{zone: {:error, :not_fetched}} = route_stop) do
    case Repo.get(route_stop.id) do
      %Stop{zone: zone} ->
        %{route_stop | zone: zone}

      _ ->
        route_stop
    end
  end

  @spec fetch_stop_features(t) :: t
  def fetch_stop_features(%__MODULE__{stop_features: {:error, :not_fetched}} = route_stop) do
    features = route_stop_features(route_stop)
    %{route_stop | stop_features: features}
  end

  def fetch_connections(
        %__MODULE__{route: %Route{}, connections: {:error, :not_fetched}} = route_stop
      ) do
    connections =
      route_stop.id
      |> Routes.Repo.by_stop()
      |> Enum.reject(&(&1.id == route_stop.route.id))

    %{route_stop | connections: connections}
  end

  @spec route_stop_features(t) :: [Repo.stop_feature()]
  defp route_stop_features(%__MODULE__{station_info: %Stop{}} = route_stop) do
    Repo.stop_features(route_stop.station_info, connections: route_stop.connections)
  end

  defp route_stop_features(%__MODULE__{}) do
    []
  end

  # Sometimes we'll get a list of stops that extend another line.
  # The CR-Newburyport direction 0 test shows a common example of this -
  # a shuttle replaces normal service for the end one branch.
  # In this sort of case we want to stitch the stops for this shuttle onto
  # the existing branch.
  @spec maybe_stitch_chunks([[RouteStop.t()]]) :: [[RouteStop.t()]]
  defp maybe_stitch_chunks(route_stop_groups) do
    route_stop_groups
    |> Enum.reduce([], fn route_stops, acc ->
      case Enum.find_index(acc, &(linked_patterns(&1, route_stops) != 0)) do
        nil ->
          acc ++ [route_stops]

        index ->
          List.update_at(acc, index, &stitch(&1, route_stops))
      end
    end)
  end

  # Determine whether 2 route stop lists are linked.
  # Returns:
  #   -1 if b starts where a ended
  #   1 if a starts where b ended
  #   0 otherwise
  @spec linked_patterns([RouteStop.t()], [RouteStop.t()]) :: -1 | 0 | 1
  defp linked_patterns(a, b),
    do: do_linked_patterns(first_last_stops(a), first_last_stops(b))

  @typep first_last_stop_ids :: {Stop.id_t(), Stop.id_t()}
  @spec first_last_stops([RouteStop.t()]) :: first_last_stop_ids()
  defp first_last_stops(route_stops) do
    {
      route_stops |> List.first() |> Map.get(:id),
      route_stops |> List.last() |> Map.get(:id)
    }
  end

  @spec do_linked_patterns(
          first_last_stop_ids(),
          first_last_stop_ids()
        ) :: -1 | 0 | 1
  defp do_linked_patterns({first_stop_a, _}, {_, last_stop_b})
       when first_stop_a == last_stop_b,
       do: 1

  defp do_linked_patterns({_, last_stop_a}, {first_stop_b, _})
       when last_stop_a == first_stop_b,
       do: -1

  defp do_linked_patterns(_, _), do: 0

  @spec stitch([RouteStop.t()], [RouteStop.t()]) :: [RouteStop.t()]
  defp stitch(a, b) do
    if linked_patterns(a, b) == -1, do: do_stitch(a, b), else: do_stitch(b, a)
  end

  @spec do_stitch([RouteStop.t()], [RouteStop.t()]) :: [RouteStop.t()]
  defp do_stitch(first, second) do
    {first_last, first_body} = List.pop_at(first, -1)

    first_body ++
      [%RouteStop{first_last | is_terminus?: false}] ++
      (second |> tl() |> Enum.map(&%RouteStop{&1 | branch: branch(first)}))
  end

  @spec branch([RouteStop.t()]) :: RouteStop.branch_name_t()
  defp branch([%RouteStop{branch: branch} | _]), do: branch

  @spec merge_branch_list([[RouteStop.t()]], direction_id_t, boolean) :: [RouteStop.t()]
  defp merge_branch_list(branches, direction_id, prefer_shorter_trunk \\ false) do
    # Attempt to flatten a collection of RouteStop lists into a single list consisting of a shared
    # "trunk" (where `branch` is set to nil) and two or more "branches" (where it is left alone).
    # If the routes split, then merge, then split again, only the final split will be represented
    # as "branches" and all but one of the multiple "trunks" will be discarded. Normally the kept
    # trunk will be the one with the most stops; `prefer_shorter_trunk` instead keeps the one with
    # the fewest stops.
    branches
    |> Enum.map(&flip_branches_to_front(&1, direction_id))
    |> flatten_branches(prefer_shorter_trunk)
    |> flip_branches_to_front(direction_id)
  end

  @spec flatten_branches([[RouteStop.t()]], boolean) :: [RouteStop.t()]
  defp flatten_branches(branches, prefer_shorter_trunk) do
    # We build a list of the shared stops between the branches, then unassign
    # the branch for each stop that's in the list of shared stops.
    shared_stop_ids =
      branches
      |> Enum.map(fn stops ->
        MapSet.new(stops, & &1.id)
      end)
      |> Enum.reduce(&MapSet.intersection/2)

    branches
    |> Enum.map(&unassign_branch_if_shared(&1, shared_stop_ids))
    |> Enum.reduce(&merge_two_branches(&1, &2, prefer_shorter_trunk))
  end

  @spec unassign_branch_if_shared([RouteStop.t()], MapSet.t()) :: [RouteStop.t()]
  defp unassign_branch_if_shared(stops, shared_stop_ids) do
    for stop <- stops do
      if MapSet.member?(shared_stop_ids, stop.id) do
        %{stop | branch: nil}
      else
        stop
      end
    end
  end

  @spec merge_two_branches([RouteStop.t()], [RouteStop.t()], boolean) :: [RouteStop.t()]
  defp merge_two_branches(first, second, prefer_shorter_trunk) do
    {first_branch, first_core} = Enum.split_while(first, & &1.branch)
    {second_branch, second_core} = Enum.split_while(second, & &1.branch)

    max_or_min_by = if(prefer_shorter_trunk, do: &Enum.min_by/2, else: &Enum.max_by/2)

    core =
      [first_core, second_core]
      |> max_or_min_by.(&length/1)
      |> Enum.map(&%{&1 | branch: nil})

    second_branch ++ first_branch ++ core
  end

  @spec flip_branches_to_front([RouteStop.t()], direction_id_t) :: [RouteStop.t()]
  defp flip_branches_to_front(branch, 0), do: Enum.reverse(branch)
  defp flip_branches_to_front(branch, 1), do: branch

  defimpl Util.Position do
    def latitude(route_stop), do: route_stop.station_info.latitude
    def longitude(route_stop), do: route_stop.station_info.longitude
  end
end
