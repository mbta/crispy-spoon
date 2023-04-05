defmodule Fares.OneWay do
  @moduledoc """
  Calculates the lowest, highest and reduced one-way fares for a particular trip for the given mode.
  Commuter rail and ferry fares distinguish between the possible sets of stops.
  Bus fares for express buses do not distinguish between the local and express portions;
  the express fare is always returned.
  """

  alias Fares.{Fare, Repo}
  alias Routes.Route
  alias Schedules.Trip

  @default_filters [duration: :single_trip]
  @default_foxboro_filters [duration: :round_trip]

  @default_trip %Trip{name: "", id: ""}

  @spec recommended_fare(
          Route.t() | map,
          Trip.t() | map,
          Stops.Stop.id_t(),
          Stops.Stop.id_t(),
          (Keyword.t() -> [Fare.t()])
        ) ::
          Fare.t() | nil
  def recommended_fare(route, trip, origin_id, destination_id, fare_fn \\ &Repo.all/1)
  def recommended_fare(nil, _, _, _, _), do: nil

  def recommended_fare(route, nil, origin_id, destination_id, fare_fn) do
    recommended_fare(route, @default_trip, origin_id, destination_id, fare_fn)
  end

  def recommended_fare(route, trip, origin_id, destination_id, fare_fn) do
    route
    |> get_fares(trip, origin_id, destination_id, fare_fn)
    |> Enum.filter(fn fare -> fare.reduced == nil end)
    |> Enum.min_by(& &1.cents, fn -> nil end)
  end

  @spec base_fare(
          Route.t() | map,
          Trip.t() | map,
          Stops.Stop.id_t(),
          Stops.Stop.id_t(),
          (Keyword.t() -> [Fare.t()])
        ) ::
          Fare.t() | nil
  def base_fare(route, trip, origin_id, destination_id, fare_fn \\ &Repo.all/1)
  def base_fare(nil, _, _, _, _), do: nil

  def base_fare(route, nil, origin_id, destination_id, fare_fn) do
    base_fare(route, @default_trip, origin_id, destination_id, fare_fn)
  end

  def base_fare(route, trip, origin_id, destination_id, fare_fn) do
    route
    |> get_fares(trip, origin_id, destination_id, fare_fn)
    |> Enum.filter(fn fare -> fare.reduced == nil end)
    |> Enum.max_by(& &1.cents, fn -> nil end)
  end

  @spec reduced_fare(
          Route.t() | map,
          Trip.t() | map,
          Stops.Stop.id_t(),
          Stops.Stop.id_t(),
          (Keyword.t() -> [Fare.t()])
        ) ::
          Fare.t() | nil
  def reduced_fare(route, trip, origin_id, destination_id, fare_fn \\ &Repo.all/1)

  def reduced_fare(nil, _, _, _, _), do: nil

  def reduced_fare(route, trip, origin_id, destination_id, fare_fn) do
    # The reduced fare is always the same so we just return any element from the list
    route
    |> get_fares(trip, origin_id, destination_id, fare_fn)
    |> Enum.filter(fn fare -> fare.reduced != nil end)
    |> List.first()
  end

  @spec get_fares(
          Route.t() | map,
          Trip.t() | map,
          Stops.Stop.id_t(),
          Stops.Stop.id_t(),
          (Keyword.t() -> [Fare.t()])
        ) ::
          [Fare.t() | nil]
  defp get_fares(route, trip, origin_id, destination_id, fare_fn) do
    route_filters =
      route.type
      |> Route.type_atom()
      |> name_or_mode_filter(route, origin_id, destination_id, trip)

    default_filters =
      if {:name, :foxboro} in route_filters do
        @default_foxboro_filters
      else
        @default_filters
      end

    default_filters
    |> Keyword.merge(route_filters)
    |> fare_fn.()
  end

  defp name_or_mode_filter(:subway, _route, _origin_id, _destination_id, _trip) do
    [mode: :subway]
  end

  defp name_or_mode_filter(_, %{description: :rail_replacement_bus}, _, _, _) do
    [name: :free_fare]
  end

  defp name_or_mode_filter(_, %{id: "CR-Foxboro"}, _, _, _) do
    [name: :foxboro]
  end

  defp name_or_mode_filter(:bus, %{id: route_id}, origin_id, _destination_id, _trip) do
    name =
      cond do
        Fares.express?(route_id) -> :express_bus
        Fares.silver_line_airport_stop?(route_id, origin_id) -> :free_fare
        Fares.silver_line_rapid_transit?(route_id) -> :subway
        true -> :local_bus
      end

    [name: name]
  end

  defp name_or_mode_filter(:commuter_rail, _, origin_id, destination_id, trip) do
    case Fares.fare_for_stops(:commuter_rail, origin_id, destination_id, trip) do
      {:ok, name} ->
        [name: name]

      :error ->
        [mode: :commuter_rail]
    end
  end

  defp name_or_mode_filter(:ferry, _, origin_id, destination_id, _) do
    [name: :ferry |> Fares.fare_for_stops(origin_id, destination_id) |> elem(1)]
  end

  defp name_or_mode_filter(:massport_shuttle, %{id: route_id}, _origin_id, _destination_id, _trip) do
    [name: route_id]
  end
end
