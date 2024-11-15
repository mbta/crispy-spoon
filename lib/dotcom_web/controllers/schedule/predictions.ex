defmodule DotcomWeb.ScheduleController.Predictions do
  @moduledoc """

  Assigns predictions based on the currently selected route/stop/direction.

  """

  require Logger

  import Plug.Conn

  alias Predictions.Prediction
  alias Util.AsyncAssign

  @predictions_repo Application.compile_env!(:dotcom, :repo_modules)[:predictions]

  @behaviour Plug

  @impl true
  def init(opts \\ []), do: opts

  @impl true
  def call(conn, _opts \\ []) do
    Util.log_duration(__MODULE__, :do_call, [conn])
  end

  def do_call(conn) do
    if should_fetch_predictions?(conn) do
      predictions_task = fn -> predictions(conn) end
      vehicle_predictions_task = fn -> vehicle_predictions(conn) end

      conn
      |> AsyncAssign.async_assign_default(:predictions, predictions_task, [])
      |> AsyncAssign.async_assign_default(:vehicle_predictions, vehicle_predictions_task, [])
      |> AsyncAssign.await_assign_all_default(__MODULE__)
    else
      conn
      |> assign(:predictions, [])
      |> assign(:vehicle_predictions, [])
    end
  end

  @spec should_fetch_predictions?(Plug.Conn.t()) :: boolean
  @doc "We only fetch predictions if we selected an origin and the date is today."
  def should_fetch_predictions?(%{assigns: %{origin: nil}}) do
    false
  end

  def should_fetch_predictions?(%{assigns: assigns}) do
    Date.compare(assigns.date, Util.service_date(assigns.date_time)) == :eq
  end

  @spec predictions(Plug.Conn.t()) :: [Prediction.t()]
  def predictions(%{
        assigns: %{
          origin: origin,
          destination: destination,
          route: %{id: route_id},
          direction_id: direction_id
        }
      })
      when not is_nil(origin) do
    destination_id = if destination, do: Map.get(destination, :id)

    opts =
      if destination_id do
        [route: route_id]
      else
        [route: route_id, direction_id: direction_id]
      end

    @predictions_repo.all(opts)
    |> case do
      {:error, error} ->
        Logger.error("predictions for opts #{inspect(opts)}: #{inspect(error)}")

        []

      list ->
        list
        |> Enum.filter(fn prediction ->
          prediction.stop && prediction.stop.id in [origin.id, destination_id]
        end)
        |> filter_stop_at_origin(origin.id)
        |> filter_missing_trip
    end
  end

  def predictions(_conn) do
    []
  end

  @spec filter_stop_at_origin([Prediction.t()], Stops.Stop.id_t()) :: [Prediction.t()]
  defp filter_stop_at_origin(predictions, origin_id) do
    predictions
    |> Enum.reject(fn
      %Prediction{time: nil} -> false
      %Prediction{stop: %{id: ^origin_id}, departing?: false} -> true
      %Prediction{} -> false
    end)
  end

  @spec filter_missing_trip([Prediction.t()]) :: [Prediction.t()]
  defp filter_missing_trip(predictions) do
    Enum.filter(predictions, fn pred ->
      pred.trip != nil || pred.status != nil
    end)
  end

  @spec vehicle_predictions(Plug.Conn.t()) :: [Prediction.t()]
  def vehicle_predictions(%{assigns: %{vehicle_locations: vehicle_locations}}) do
    {trip_ids, stop_ids} =
      vehicle_locations
      |> Map.keys()
      |> Enum.unzip()

    trip_ids = trip_ids |> Enum.reject(&is_nil/1) |> Enum.join(",")

    case @predictions_repo.all(trip: trip_ids) do
      {:error, error} ->
        Logger.error("predictions for trips #{inspect(trip_ids)}: #{inspect(error)}")

        []

      list ->
        list
        |> Enum.filter(&(&1.stop && &1.stop.id in stop_ids))
    end
  end

  def vehicle_predictions(_conn) do
    []
  end
end
