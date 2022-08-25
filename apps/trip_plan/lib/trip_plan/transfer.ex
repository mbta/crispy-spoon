defmodule TripPlan.Transfer do
  @moduledoc """
    Tools for handling logic around transfers between transit legs and modes.
    The MBTA allows transfers between services depending on the fare media used
    and the amount paid.

    This logic may be superseded by the upcoming fares work.
  """
  alias TripPlan.{Leg, NamedPosition, TransitDetail}

  # Paying a single-ride fare for the first may get you a transfer to the second
  # (can't be certain, as it depends on media used)!
  @single_ride_transfers %{
    :bus => [:subway, :bus],
    :subway => [:subway, :bus],
    :express_bus => [:subway, :bus, :express_bus]
  }

  @multi_ride_transfers %{
    :bus => [:bus, :bus, :subway],
    :subway => [:subway, :bus, :bus]
  }

  @doc "Searches a list of legs for evidence of an in-station subway transfer."
  @spec is_subway_transfer?([Leg.t()]) :: boolean
  def is_subway_transfer?([
        %Leg{to: %NamedPosition{stop_id: to_stop}, mode: %TransitDetail{route_id: route_to}},
        %Leg{
          from: %NamedPosition{stop_id: from_stop},
          mode: %TransitDetail{route_id: route_from}
        }
        | _
      ]) do
    same_station?(from_stop, to_stop) and is_subway?(route_to) and is_subway?(route_from)
  end

  def is_subway_transfer?([_ | legs]), do: is_subway_transfer?(legs)

  def is_subway_transfer?(_), do: false

  @doc """
  Takes a set of legs and returns true if there might be a transfer between the legs, based on the lists in @single_ride_transfers and @multi_ride_transfers.

  Exceptions:
  - no transfers from bus route to same bus route
  - no transfers from a shuttle to any other mode
  """
  @spec is_maybe_transfer?([Leg.t()]) :: boolean
  def is_maybe_transfer?([%Leg{mode: %TransitDetail{route_id: "Shuttle-" <> _}} | _]), do: false

  def is_maybe_transfer?([
        first_leg = %Leg{mode: %TransitDetail{route_id: first_route}},
        middle_leg = %Leg{mode: %TransitDetail{route_id: middle_route}},
        last_leg = %Leg{mode: %TransitDetail{route_id: last_route}}
      ]) do
    @multi_ride_transfers
    |> Map.get(Fares.to_fare_atom(first_route), [])
    |> Kernel.==(Enum.map([first_route, middle_route, last_route], &Fares.to_fare_atom/1))
    |> Kernel.and(is_maybe_transfer?([first_leg, middle_leg]))
    |> Kernel.and(is_maybe_transfer?([middle_leg, last_leg]))
  end

  def is_maybe_transfer?([
        %Leg{mode: %TransitDetail{route_id: from_route}},
        %Leg{mode: %TransitDetail{route_id: to_route}}
      ]) do
    if from_route === to_route and
         Enum.all?([from_route, to_route], &is_bus?/1) do
      false
    else
      @single_ride_transfers
      |> Map.get(Fares.to_fare_atom(from_route), [])
      |> Enum.member?(Fares.to_fare_atom(to_route))
    end
  end

  def is_maybe_transfer?(_), do: false

  defp same_station?(from_stop, to_stop) do
    to_parent_stop = Stops.Repo.get_parent(to_stop)
    from_parent_stop = Stops.Repo.get_parent(from_stop)

    cond do
      is_nil(to_parent_stop) or is_nil(from_parent_stop) ->
        false

      to_parent_stop == from_parent_stop ->
        true

      true ->
        # Check whether this is DTX <-> Park St via. the Winter St. Concourse
        uses_concourse?(to_parent_stop, from_parent_stop)
    end
  end

  defp is_bus?(route), do: Fares.to_fare_atom(route) == :bus
  def is_subway?(route), do: Fares.to_fare_atom(route) == :subway

  defp uses_concourse?(%Stops.Stop{id: "place-pktrm"}, %Stops.Stop{id: "place-dwnxg"}),
    do: true

  defp uses_concourse?(%Stops.Stop{id: "place-dwnxg"}, %Stops.Stop{id: "place-pktrm"}),
    do: true

  defp uses_concourse?(_, _), do: false
end
