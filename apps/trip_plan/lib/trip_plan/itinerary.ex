defmodule TripPlan.Itinerary do
  @moduledoc """
  A trip at a particular time.

  An Itinerary is a single trip, with the legs being the different types of
  travel. Itineraries are separate even if they use the same modes but happen
  at different times of day.
  """

  alias Fares.Fare
  alias Routes.Route
  alias Schedules.Trip
  alias Stops.Stop
  alias TripPlan.{Leg, NamedPosition, TransitDetail}

  @enforce_keys [:start, :stop]
  defstruct [
    :start,
    :stop,
    :passes,
    legs: [],
    accessible?: false
  ]

  @type t :: %__MODULE__{
          start: DateTime.t(),
          stop: DateTime.t(),
          legs: [Leg.t()],
          accessible?: boolean,
          passes: passes()
        }

  @type passes :: %{
          base_month_pass: Fare.t(),
          recommended_month_pass: Fare.t(),
          reduced_month_pass: Fare.t()
        }

  @spec destination(t) :: NamedPosition.t()
  def destination(%__MODULE__{legs: legs}) do
    List.last(legs).to
  end

  @spec transit_legs(t()) :: [Leg.t()]
  def transit_legs(%__MODULE__{legs: legs}), do: Enum.filter(legs, &Leg.transit?/1)

  @doc "Return a list of all the route IDs used for this Itinerary"
  @spec route_ids(t) :: [Route.id_t()]
  def route_ids(%__MODULE__{legs: legs}) do
    flat_map_over_legs(legs, &Leg.route_id/1)
  end

  @doc "Return a list of all the trip IDs used for this Itinerary"
  @spec trip_ids(t) :: [Trip.id_t()]
  def trip_ids(%__MODULE__{legs: legs}) do
    flat_map_over_legs(legs, &Leg.trip_id/1)
  end

  @doc "Return a list of {route ID, trip ID} pairs for this Itinerary"
  @spec route_trip_ids(t) :: [{Route.id_t(), Trip.id_t()}]
  def route_trip_ids(%__MODULE__{legs: legs}) do
    flat_map_over_legs(legs, &Leg.route_trip_ids/1)
  end

  @doc "Returns a list of all the named positions for this Itinerary"
  @spec positions(t) :: [NamedPosition.t()]
  def positions(%__MODULE__{legs: legs}) do
    Enum.flat_map(legs, &[&1.from, &1.to])
  end

  @doc "Return a list of all the stop IDs used for this Itinerary"
  @spec stop_ids(t) :: [Trip.id_t()]
  def stop_ids(%__MODULE__{} = itinerary) do
    itinerary
    |> positions
    |> Enum.map(& &1.stop_id)
    |> Enum.uniq()
  end

  @doc "Total walking distance over all legs, in meters"
  @spec walking_distance(t) :: float
  def walking_distance(itinerary) do
    itinerary
    |> Enum.map(&Leg.walking_distance/1)
    |> Enum.sum()
  end

  @doc "Determines if two itineraries represent the same sequence of legs at the same time"
  @spec same_itinerary?(t, t) :: boolean
  def same_itinerary?(itinerary_1, itinerary_2) do
    itinerary_1.start == itinerary_2.start && itinerary_1.stop == itinerary_2.stop &&
      same_legs?(itinerary_2, itinerary_2)
  end

  @doc "Return a lost of all of the "
  @spec intermediate_stop_ids(t) :: [Stop.id_t()]
  def intermediate_stop_ids(itinerary) do
    itinerary
    |> Enum.flat_map(&leg_intermediate/1)
    |> Enum.uniq()
  end

  defp flat_map_over_legs(legs, mapper) do
    for leg <- legs, {:ok, value} <- leg |> mapper.() |> List.wrap() do
      value
    end
  end

  @spec same_legs?(t, t) :: boolean
  defp same_legs?(%__MODULE__{legs: legs_1}, %__MODULE__{legs: legs_2}) do
    Enum.count(legs_1) == Enum.count(legs_2) &&
      legs_1 |> Enum.zip(legs_2) |> Enum.all?(fn {l1, l2} -> Leg.same_leg?(l1, l2) end)
  end

  defp leg_intermediate(%Leg{mode: %TransitDetail{intermediate_stop_ids: ids}}) do
    ids
  end

  defp leg_intermediate(_) do
    []
  end
end

defimpl Enumerable, for: TripPlan.Itinerary do
  alias TripPlan.Leg

  def count(_itinerary) do
    {:error, __MODULE__}
  end

  def member?(_itinerary, %Leg{}) do
    {:error, __MODULE__}
  end

  def member?(_itinerary, _other) do
    {:ok, false}
  end

  def reduce(%{legs: legs}, acc, fun) do
    Enumerable.reduce(legs, acc, fun)
  end

  def slice(_itinerary) do
    {:error, __MODULE__}
  end
end
