defmodule Services.Repo do
  @moduledoc """
  Retrieves services for a route.
  """

  use Nebulex.Caching.Decorators

  require Logger

  alias MBTA.Api.Services, as: ServicesApi
  alias Services.Service

  @cache Application.compile_env!(:dotcom, :cache)
  @ttl :timer.hours(1)

  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  def by_id(id) when is_binary(id) do
    ServicesApi.get(id)
    |> handle_response()
    |> List.first()
  end

  def by_route_id(route_id, params \\ [])

  def by_route_id([route_id] = route, params) when is_list(route) do
    by_route_id(route_id, params)
  end

  def by_route_id("Green", params) do
    "Green-B,Green-C,Green-D,Green-E"
    |> by_route_id(params)
  end

  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  def by_route_id(route_id, params) when is_binary(route_id) do
    params
    |> Keyword.put(:route, route_id)
    |> ServicesApi.all()
    |> handle_response()
  end

  defp handle_response(%JsonApi{data: data}) do
    Enum.map(data, &Service.new/1)
  end

  defp handle_response({:error, [%JsonApi.Error{code: code}]}) do
    Logger.warning("services_repo_handle_response_error=#{code}")

    []
  end
end
