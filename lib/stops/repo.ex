defmodule Stops.Repo do
  @moduledoc """
  Matches the Ecto API, but fetches Stops from the Stop Info API instead.
  """

  use Nebulex.Caching.Decorators

  alias Dotcom.Cache.KeyGenerator
  alias Routes.Route
  alias Stops.{Api, Repo.Behaviour, Stop}

  @cache Application.compile_env!(:dotcom, :cache)
  @ttl :timer.hours(1)

  @routes_repo Application.compile_env!(:dotcom, :repo_modules)[:routes]

  @behaviour Stops.Repo.Behaviour

  for {old_id, gtfs_id} <-
        "priv/stops/stop_id_to_gtfs.csv"
        |> File.stream!()
        |> CSV.decode!(headers: true)
        |> Enum.map(&{&1 |> Map.get("atisId") |> String.split(","), Map.get(&1, "stopID")})
        |> Enum.flat_map(fn {ids, gtfs_id} -> Enum.map(ids, &{&1, gtfs_id}) end) do
    @impl Behaviour
    def old_id_to_gtfs_id(unquote(old_id)) do
      unquote(gtfs_id)
    end
  end

  def old_id_to_gtfs_id(_) do
    nil
  end

  @impl Behaviour
  def get(id) when is_binary(id) do
    case stop(id) do
      {:ok, s} -> s
      _ -> nil
    end
  end

  @impl Behaviour
  def get!(id) do
    case stop(id) do
      {:ok, %Stop{} = s} -> s
      _ -> raise Stops.NotFoundError, message: "Could not find stop #{id}"
    end
  end

  @impl Behaviour
  def has_parent?(nil), do: false
  def has_parent?(%Stop{parent_id: nil}), do: false
  def has_parent?(%Stop{parent_id: _}), do: true

  @impl Behaviour
  def get_parent(nil), do: nil

  def get_parent(%Stop{parent_id: nil} = stop) do
    stop
  end

  def get_parent(%Stop{parent_id: parent_id}) when is_binary(parent_id) do
    case stop(parent_id) do
      {:ok, %Stop{} = stop} -> stop
      _ -> nil
    end
  end

  def get_parent(id) when is_binary(id) do
    id
    |> get()
    |> get_parent()
  end

  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  defp stop(id) do
    Api.by_gtfs_id(id)
  end

  @impl Behaviour
  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  def by_route(route_id, direction_id, opts \\ []) do
    with stops when is_list(stops) <- Api.by_route({route_id, direction_id, opts}) do
      for stop <- stops do
        key = KeyGenerator.generate(__MODULE__, :stop, stop.id)

        @cache.put(key, {:ok, stop})

        stop
      end
    end
  end

  @impl Behaviour
  def by_routes(route_ids, direction_id, opts \\ []) when is_list(route_ids) do
    # once the V3 API supports multiple route_ids in this field, we can do it
    # as a single lookup -ps
    route_ids
    |> Task.async_stream(&by_route(&1, direction_id, opts))
    |> Enum.flat_map(fn
      {:ok, stops} -> stops
      _ -> []
    end)
    |> Enum.uniq()
  end

  @impl Behaviour
  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  def by_route_type(route_type, opts \\ []) do
    {route_type, opts}
    |> Stops.Api.by_route_type()
    |> Enum.map(&get_parent/1)
    |> Enum.uniq_by(& &1.id)
  end

  @impl Behaviour
  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  def by_trip(trip_id) do
    Api.by_trip(trip_id)
  end

  @doc """
  Returns a list of the features associated with the given stop
  """
  @impl Behaviour
  def stop_features(%Stop{} = stop, opts \\ []) do
    [
      route_features(stop.id, opts),
      parking_features(stop.parking_lots),
      accessibility_features(stop.accessibility)
    ]
    |> Enum.concat()
    |> Enum.sort_by(&sort_feature_icons/1)
  end

  defp parking_features([]), do: []
  defp parking_features(_parking_lots), do: [:parking_lot]

  @spec route_features(String.t(), Keyword.t()) :: [Behaviour.stop_feature()]
  defp route_features(stop_id, opts) do
    icon_fn =
      if Keyword.get(opts, :expand_branches?) do
        &branch_feature/1
      else
        &Route.icon_atom/1
      end

    opts
    |> Keyword.get(:connections)
    |> get_stop_connections(stop_id)
    |> Enum.map(icon_fn)
    |> Enum.uniq()
  end

  @spec get_stop_connections([Route.t()] | {:error, :not_fetched} | nil, Stop.id_t()) ::
          [Route.t()]
  defp get_stop_connections(connections, _stop_id) when is_list(connections) do
    connections
  end

  defp get_stop_connections(_, stop_id) do
    @routes_repo.by_stop(stop_id)
  end

  defp branch_feature(%Route{id: "Green-B"}), do: :"Green-B"
  defp branch_feature(%Route{id: "Green-C"}), do: :"Green-C"
  defp branch_feature(%Route{id: "Green-D"}), do: :"Green-D"
  defp branch_feature(%Route{id: "Green-E"}), do: :"Green-E"
  defp branch_feature(route), do: Route.icon_atom(route)

  @spec accessibility_features([String.t()]) :: [:access]
  defp accessibility_features(["accessible" | _]), do: [:access]
  defp accessibility_features(_), do: []

  @spec sort_feature_icons(atom) :: integer
  defp sort_feature_icons(:"Green-B"), do: 0
  defp sort_feature_icons(:"Green-C"), do: 1
  defp sort_feature_icons(:"Green-D"), do: 2
  defp sort_feature_icons(:"Green-E"), do: 3
  defp sort_feature_icons(:bus), do: 5
  defp sort_feature_icons(:commuter_rail), do: 6
  defp sort_feature_icons(:access), do: 7
  defp sort_feature_icons(:parking_lot), do: 8
  defp sort_feature_icons(_), do: 4
end

defmodule Stops.NotFoundError do
  @moduledoc "Raised when we don't find a stop with the given GTFS ID"
  defexception [:message]
end
