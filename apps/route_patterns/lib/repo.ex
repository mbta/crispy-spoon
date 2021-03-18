defmodule RoutePatterns.Repo do
  @moduledoc "Repo for fetching Route resources and their associated data from the V3 API."

  @behaviour RoutePatterns.RepoApi

  require Logger
  use RepoCache, ttl: :timer.hours(1)

  alias RoutePatterns.RoutePattern
  alias Routes.Route
  alias V3Api.RoutePatterns, as: RoutePatternsApi

  @impl RoutePatterns.RepoApi
  def get(id, opts \\ []) when is_binary(id) do
    case cache({id, opts}, fn {id, opts} ->
           with %{data: [route_pattern]} <- RoutePatternsApi.get(id, opts) do
             {:ok, RoutePattern.new(route_pattern)}
           end
         end) do
      {:ok, route_pattern} -> route_pattern
      {:error, _} -> nil
    end
  end

  @impl RoutePatterns.RepoApi
  def by_route_id(route_id, opts \\ [])

  def by_route_id("Green", opts) do
    ~w(Green-B Green-C Green-D Green-E)s
    |> Enum.join(",")
    |> by_route_id(opts)
  end

  def by_route_id(route_id, opts) do
    opts
    |> Keyword.get(:direction_id)
    |> case do
      nil -> [route: route_id]
      direction_id -> [route: route_id, direction_id: direction_id]
    end
    |> Keyword.put(:sort, "typicality,sort_order")
    |> Keyword.put(:include, "representative_trip.shape")
    |> api_all
  end

  defp api_all(opts) do
    case RoutePatternsApi.all(opts) do
      {:error, error} ->
        _ =
          Logger.warn(
            "module=#{__MODULE__} RoutePatternsApi.all with opts #{inspect(opts)} returned :error -> #{
              inspect(error)
            }"
          )

        []

      %JsonApi{data: data} ->
        Enum.map(data, &RoutePattern.new/1)
    end
  end
end
