defmodule RoutePatterns.Repo do
  @moduledoc """
  Repo for fetching Route resources and their associated data from the MBTA Api.
  """

  use Nebulex.Caching.Decorators
  require Logger

  alias MBTA.Api.RoutePatterns, as: RoutePatternsApi
  alias RoutePatterns.RoutePattern

  @behaviour RoutePatterns.Repo.Behaviour

  @cache Application.compile_env!(:dotcom, :cache)
  @ttl :timer.hours(1)

  @impl RoutePatterns.Repo.Behaviour
  def get(id, opts \\ []) when is_binary(id) do
    case get_id(id, opts) do
      {:ok, route_pattern} -> route_pattern
      {:error, _} -> nil
    end
  end

  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  defp get_id(id, opts) do
    with %{data: [route_pattern]} <- RoutePatternsApi.get(id, opts) do
      {:ok, RoutePattern.new(route_pattern)}
    end
  end

  @impl RoutePatterns.Repo.Behaviour
  def by_route_id(route_id, opts \\ [])

  def by_route_id("Green", opts) do
    ~w(Green-B Green-C Green-D Green-E)s
    |> Enum.join(",")
    |> by_route_id(opts)
  end

  def by_route_id(route_id, opts) do
    opts
    |> Keyword.put(:route, route_id)
    |> Keyword.put(:sort, "typicality,sort_order")
    |> api_all()
    |> Enum.sort(&reorder_mrts(&1, &2, route_id))
  end

  @impl RoutePatterns.Repo.Behaviour
  def by_stop_id(stop_id) do
    [stop: stop_id]
    |> Keyword.put(:include, "representative_trip.shape,representative_trip.stops")
    |> api_all()
  end

  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  defp api_all(opts) do
    case RoutePatternsApi.all(opts) do
      {:error, error} ->
        _ =
          Logger.warning(
            "module=#{__MODULE__} RoutePatternsApi.all with opts #{inspect(opts)} returned :error -> #{inspect(error)}"
          )

        []

      %JsonApi{data: data} ->
        Enum.map(data, &RoutePattern.new/1)
    end
  end

  @spec reorder_mrts(RoutePattern.t(), RoutePattern.t(), String.t()) :: boolean()
  defp reorder_mrts(pattern_one, pattern_two, route_id) do
    not (pattern_one.route_id !== route_id and pattern_one.typicality == pattern_two.typicality)
  end
end
