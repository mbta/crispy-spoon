defmodule Site.ShuttleDiversion do
  @moduledoc "Represents and retrieves data about rail-replacement shuttle bus services."

  alias Alerts.Match, as: AlertsMatch
  alias Alerts.Repo, as: Alerts
  alias Routes.Route
  alias Stops.Repo, as: Stops
  alias V3Api.Trips

  defmodule Shape do
    @moduledoc "Derivative of an API `shape` tailored for drawing a shuttle diversion map."

    @enforce_keys [:id, :direction_id, :polyline, :is_shuttle_route]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            id: String.t(),
            direction_id: 0 | 1,
            polyline: [[float]],
            is_shuttle_route: boolean
          }
  end

  defmodule Stop do
    @moduledoc "Derivative of an API `stop` tailored for drawing a shuttle diversion map."

    @enforce_keys [:id, :name, :type, :latitude, :longitude]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            type: :rail_unaffected | :rail_affected | :shuttle,
            latitude: float,
            longitude: float
          }
  end

  @enforce_keys [:shapes, :stops]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          shapes: [Shape.t()],
          stops: [Stop.t()]
        }

  @doc "Indicates whether there are any shuttle diversions on the given routes at a given time."
  @spec active?([Route.id_t()], DateTime.t()) :: boolean
  def active?(route_ids, time \\ Util.now()) do
    Enum.any?(ongoing_shuttle_alerts(route_ids, time))
  end

  @doc "Retrieves data relevant to all shuttle diversions on the given routes at a given time."
  @spec active([Route.id_t()], DateTime.t()) :: {:ok, t()} | {:error, any}
  def active(route_ids, time \\ Util.now()) do
    if active?(route_ids, time) do
      true_route_ids = expand_route_ids(route_ids)
      trips_route = Enum.join(true_route_ids, ",")

      trips_params = [
        "filter[date]": time |> Util.service_date() |> Date.to_iso8601(),
        include: "route,service,shape,shape.stops"
      ]

      with %JsonApi{data: trips} <- Trips.by_route(trips_route, trips_params),
           route_stops when is_list(route_stops) <- Stops.by_routes(true_route_ids, 0),
           relevant_trips = shuttle_related_trips(trips) do
        {:ok,
         %__MODULE__{
           shapes: build_shapes(relevant_trips),
           stops: build_stops(route_ids, route_stops, relevant_trips, time)
         }}
      end
    else
      {:ok, %__MODULE__{shapes: [], stops: []}}
    end
  end

  defp build_shapes(trips) do
    Enum.map(trips, fn trip ->
      with shape <- shape(trip) do
        %Shape{
          id: shape.id,
          direction_id: shape.attributes["direction_id"],
          polyline: decode_polyline(shape.attributes["polyline"]),
          is_shuttle_route: shuttle_route?(trip)
        }
      end
    end)
  end

  defp build_stops(route_ids, route_stops, trips, time) do
    build_rail_stops(route_ids, route_stops, time) ++ build_shuttle_stops(trips)
  end

  defp build_rail_stops(route_ids, route_stops, time) do
    affected_stop_ids =
      route_ids
      |> ongoing_shuttle_alerts(time)
      |> Enum.flat_map(& &1.informed_entity.entities)
      |> Enum.map(&Stops.get_parent(&1.stop))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    Enum.map(route_stops, fn stop ->
      %Stop{
        id: stop.id,
        name: stop.name,
        type: if(stop.id in affected_stop_ids, do: :rail_affected, else: :rail_unaffected),
        latitude: stop.latitude,
        longitude: stop.longitude
      }
    end)
  end

  defp build_shuttle_stops(trips) do
    trips
    |> Stream.filter(&shuttle_route?/1)
    |> Stream.flat_map(&stops/1)
    |> Stream.uniq_by(& &1.id)
    |> Enum.map(fn stop ->
      %Stop{
        id: stop.id,
        name: stop.attributes["name"],
        type: :shuttle,
        latitude: stop.attributes["latitude"],
        longitude: stop.attributes["longitude"]
      }
    end)
  end

  defp decode_polyline(encoded_line) do
    encoded_line |> Polyline.decode() |> Enum.map(fn {lng, lat} -> [lat, lng] end)
  end

  # Allow the otherwise-invalid route ID "Green" to stand in for all Green Line routes.
  defp expand_route_ids(["Green" | rest]), do: GreenLine.branch_ids() ++ expand_route_ids(rest)
  defp expand_route_ids([route_id | rest]), do: [route_id | expand_route_ids(rest)]
  defp expand_route_ids([]), do: []

  defp ongoing_shuttle_alerts(route_ids, time) do
    route_ids
    |> Alerts.by_route_ids(time)
    |> Enum.filter(&(&1.effect == :shuttle and AlertsMatch.any_time_match?(&1, time)))
  end

  defp shape(%{relationships: %{"shape" => [shape]}}), do: shape
  defp shape(_trip), do: nil

  defp shuttle_related_trips(trips) do
    trips
    |> Stream.filter(&shape/1)
    |> Stream.uniq_by(&shape/1)
    |> Stream.filter(&shuttle_related?/1)
  end

  defp shuttle_related?(trip) do
    # Typicality 4 indicates major changes in service due to a planned disruption. This might not
    # always mean there's a shuttle service, but it's the best identifying attribute we have.
    hd(trip.relationships["service"]).attributes["schedule_typicality"] == 4
  end

  defp shuttle_route?(trip) do
    # Route type 3 indicates a bus route — not specifically a shuttle route, so this only works
    # when the "replaced" route is something other than a bus (e.g. rail).
    hd(trip.relationships["route"]).attributes["type"] == 3
  end

  defp stops(%{relationships: %{"shape" => [%{relationships: %{"stops" => stops}}]}}), do: stops
  defp stops(_trip), do: []
end
