defmodule DotcomWeb.ScheduleController.Journeys do
  @moduledoc """
  Assigns a list of journeys based on predictions, schedules, origin, and destination. The bulk of
  the work happens in JourneyList.
  """
  use Plug.Builder

  require Routes.Route

  import Plug.Conn, only: [assign: 3, halt: 1]
  import Phoenix.Controller, only: [redirect: 2]
  import UrlHelpers, only: [update_url: 2]

  alias Routes.Route

  plug(:do_assign_journeys)
  plug(:validate_direction_id)

  defp do_assign_journeys(conn, opts) do
    Util.log_duration(__MODULE__, :assign_journeys, [conn, opts])
  end

  def assign_journeys(
        %Plug.Conn{
          assigns: %{route: %Routes.Route{type: route_type, id: route_id}, schedules: schedules}
        } = conn,
        []
      )
      when Route.subway?(route_type, route_id) do
    schedules = Util.error_default(schedules, [])
    destination_id = Util.safe_id(conn.assigns.destination)
    origin_id = Util.safe_id(conn.assigns.origin)
    predictions = Util.error_default(conn.assigns.predictions, [])

    journeys =
      JourneyList.build_predictions_only(schedules, predictions, origin_id, destination_id)

    assign(conn, :journeys, journeys)
  end

  def assign_journeys(
        %Plug.Conn{
          assigns: %{
            route: %Routes.Route{type: route_type, id: route_id} = route,
            schedules: schedules
          }
        } = conn,
        []
      ) do
    schedules = Util.error_default(schedules, [])
    show_all_trips? = conn.params["show_all_trips"] == "true"
    destination_id = Util.safe_id(conn.assigns.destination)
    origin_id = Util.safe_id(conn.assigns.origin)
    predictions = Util.error_default(conn.assigns.predictions, [])
    user_selected_date = conn.assigns.date
    current_date_time = conn.assigns.date_time
    today? = Date.diff(user_selected_date, current_date_time) == 0
    current_time = if today?, do: conn.assigns.date_time, else: nil
    filter_flag = filter_flag(route)
    keep_all? = keep_all?(today?, route_type, route_id, show_all_trips?)

    journey_optionals = [
      origin_id: origin_id,
      destination_id: destination_id,
      current_time: current_time
    ]

    assign(
      conn,
      :journeys,
      JourneyList.build(schedules, predictions, filter_flag, keep_all?, journey_optionals)
    )
  end

  def assign_journeys(conn, []) do
    conn
  end

  def validate_direction_id(
        %Plug.Conn{assigns: %{direction_id: direction_id, journeys: journeys}} = conn,
        []
      ) do
    case Enum.find(journeys, &(!is_nil(&1.trip))) do
      nil ->
        conn

      journey ->
        if journey.trip.direction_id != direction_id do
          url = update_url(conn, direction_id: journey.trip.direction_id)

          conn
          |> redirect(to: url)
          |> halt
        else
          conn
        end
    end
  end

  def validate_direction_id(conn, []) do
    conn
  end

  defp keep_all?(today?, route_type, route_id, show_all?) do
    show_all? || !today? || Route.subway?(route_type, route_id)
  end

  @spec filter_flag(Routes.Route.t()) :: Journey.Filter.filter_flag_t()
  def filter_flag(%Routes.Route{type: 3}), do: :predictions_then_schedules
  def filter_flag(%Routes.Route{type: 0, id: "Mattapan"}), do: :predictions_then_schedules
  def filter_flag(_route), do: :last_trip_and_upcoming
end
