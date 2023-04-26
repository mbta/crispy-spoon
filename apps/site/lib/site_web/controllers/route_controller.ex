defmodule SiteWeb.RouteController do
  @moduledoc """
  Endpoints for getting route data.
  """
  use SiteWeb, :controller
  alias RoutePatterns.RoutePattern
  alias Routes.{Repo, Route}

  def get_by_stop_id(conn, %{"stop_id" => stop_id} = _params) do
    routesWithPolylines =
      stop_id
      |> Repo.by_stop()
      |> Enum.map(&[&1, route_polylines(&1)])

    json(conn, routesWithPolylines)
  end

  defp route_polylines(route, stop_id) do
    if is_rail_route?(route) or Route.silver_line?(route) do
      route.id
      |> RoutePatterns.Repo.by_route_id(stop: stop_id)
      |> Enum.map(fn %RoutePattern{shape_id: id, representative_trip_polyline: polyline} ->
        positions =
          polyline
          |> Polyline.decode()
          |> Enum.map(fn {lng, lat} -> [lat, lng] end)

        %Leaflet.MapData.Polyline{
          id: id,
          color: "#" <> route.color,
          dotted?: false,
          positions: positions,
          weight: 4
        }
      end)
    else
      []
    end
  end

  defp is_rail_route?(route) do
    Route.type_atom(route) in [:subway, :commuter_rail]
  end
end
