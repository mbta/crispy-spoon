defmodule TripInfo do
  @moduledoc """
  Wraps the important information about a trip.

  * route: the %Routes.Route{} the trip is on
  * origin_id: the ID of the stop where we consider the trip to start.
    This is either the real start, or the origin the user selected.
  * destination_id: the ID of the stop where we consider the trip to end.
    This is either the real end, or the destination that the user selected.
  * vehicle: a %Vehicles.Vehicle{} that's on this trip, or nil
  * status: a text status of the trip relative to the schedule
  * times: a list of PredictedSchedules, for stops between either
    1) the origin and destination or 2) the vehicle and destination
  * duration: the number of minutes the trip takes between origin_id and destination_id
  * base_fare: The minimum, non-discounted, one-way fare for the trip
  """

  require Routes.Route

  alias Fares.OneWay

  @stops_repo Application.compile_env!(:dotcom, :repo_modules)[:stops]

  @type time :: PredictedSchedule.t()
  @type time_list :: [time]
  @type t :: %__MODULE__{
          route: Routes.Route.t(),
          origin_id: String.t(),
          destination_id: String.t(),
          vehicle: Vehicles.Vehicle.t() | nil,
          vehicle_stop_name: String.t() | nil,
          status: String.t(),
          times: time_list,
          duration: pos_integer | nil,
          base_fare: Fares.Fare.t()
        }

  defstruct route: nil,
            origin_id: nil,
            destination_id: nil,
            vehicle: nil,
            vehicle_stop_name: nil,
            status: "operating at normal schedule",
            times: [],
            duration: -1,
            base_fare: nil

  @doc """
  Given a list of times and options, creates a new TripInfo struct or returns an error.
  """
  @spec from_list(time_list, Keyword.t()) :: TripInfo.t() | {:error, any}
  def from_list(times, opts \\ []) do
    origin_id = time_stop_id(opts[:origin_id], times, :first)
    destination_id = time_stop_id(opts[:destination_id], times, :last)
    vehicle_stop_name = opts[:vehicle_stop_name]

    starting_stop_ids =
      if opts[:vehicle] do
        vehicle_stop = @stops_repo.get_parent(opts[:vehicle].stop_id)
        [origin_id, if(vehicle_stop, do: Map.get(vehicle_stop, :id))]
      else
        [origin_id]
      end

    times
    |> clamp_times_to_origin_destination(origin_id, destination_id)
    |> do_from_list(starting_stop_ids, destination_id, vehicle_stop_name, opts)
  end

  # finds a stop ID.  If one isn't provided, or is provided as nil, then
  # use a List function to get the stop ID from the times list.
  @spec time_stop_id(String.t(), time_list, :first | :last) :: String.t() | nil
  defp time_stop_id(stop_id_from_opts, times, list_function)

  defp time_stop_id(stop_id, _, _) when is_binary(stop_id) do
    stop_id
  end

  defp time_stop_id(_, [], _) do
    nil
  end

  defp time_stop_id(_, times, list_function) do
    List
    |> apply(list_function, [times])
    |> PredictedSchedule.stop()
    |> Map.get(:id)
  end

  defp do_from_list(
         [time, _ | _] = times,
         [origin_id | _],
         destination_id,
         vehicle_stop_name,
         opts
       )
       when is_binary(origin_id) and is_binary(destination_id) do
    route = PredictedSchedule.route(time)
    duration = duration(times, origin_id)
    base_fare = OneWay.recommended_fare(route, origin_id, destination_id)

    %TripInfo{
      route: route,
      origin_id: origin_id,
      destination_id: destination_id,
      vehicle: opts[:vehicle],
      times: times,
      duration: duration,
      vehicle_stop_name: vehicle_stop_name,
      base_fare: base_fare
    }
  end

  defp do_from_list(_times, _starting_stop_ids, _destination_id, _vehicle_stop_name, _opts) do
    {:error, "not enough times to build a trip"}
  end

  # Filters the list of times to those between origin and destination,
  # inclusive.  If the origin is after the trip, or one/both are not
  # included, the behavior is undefined.
  @spec clamp_times_to_origin_destination(time_list, String.t(), String.t()) :: time_list
  defp clamp_times_to_origin_destination(times, origin_id, destination_id) do
    case Enum.drop_while(times, &(origin_id != PredictedSchedule.stop(&1).id)) do
      [origin | rest] ->
        [origin | clamp_to_destination(rest, destination_id, [])]

      [] ->
        []
    end
  end

  defp clamp_to_destination([], _destination_id, _acc) do
    # if we get to the end of the list without finding the destination, don't
    # return anything.
    []
  end

  defp clamp_to_destination([time | rest], destination_id, acc) do
    if PredictedSchedule.stop(time).id == destination_id do
      [time | acc]
      |> Enum.reverse()
    else
      clamp_to_destination(rest, destination_id, [time | acc])
    end
  end

  defp duration(times, origin_id) do
    first = Enum.find(times, &(PredictedSchedule.stop(&1).id == origin_id))
    last = List.last(times)
    duration_diff(PredictedSchedule.time(last), PredictedSchedule.time(first))
  end

  @spec duration_diff(DateTime.t() | nil, DateTime.t() | nil) ::
          Timex.Duration.t() | integer | {:error, term}
  defp duration_diff(nil, _), do: nil
  defp duration_diff(_, nil), do: nil
  defp duration_diff(last, first), do: Timex.diff(last, first, :minutes)
end
