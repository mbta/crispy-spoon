defmodule DotcomWeb.ScheduleController do
  use DotcomWeb, :controller

  require Logger

  alias Routes.Route
  alias Schedules.Schedule

  plug(DotcomWeb.Plugs.Route when action not in [:cape_flyer, :schedules_for_stop])

  @spec show(Plug.Conn.t(), map) :: Phoenix.HTML.Safe.t()
  def show(%{query_params: %{"tab" => "timetable"} = query_params} = conn, _params) do
    tab_redirect(
      conn,
      timetable_path(conn, :show, conn.assigns.route.id, Map.delete(query_params, "tab"))
    )
  end

  def show(%{query_params: %{"tab" => "line"} = query_params} = conn, _params) do
    tab_redirect(
      conn,
      line_path(conn, :show, conn.assigns.route.id, Map.delete(query_params, "tab"))
    )
  end

  def show(%{query_params: %{"tab" => "alerts"} = query_params} = conn, _params) do
    tab_redirect(
      conn,
      alerts_path(conn, :show, conn.assigns.route.id, Map.delete(query_params, "tab"))
    )
  end

  def show(
        %{assigns: %{route: %Route{type: mode, id: route_id}}, query_params: query_params} = conn,
        _params
      )
      when mode in [2, 4] do
    tab_redirect(conn, timetable_path(conn, :show, route_id, query_params))
  end

  def show(%{assigns: %{route: %Route{id: route_id}}, query_params: query_params} = conn, _params) do
    tab_redirect(conn, line_path(conn, :show, route_id, query_params))
  end

  defp tab_redirect(conn, path) do
    conn
    |> redirect(to: path)
    |> halt()
  end

  @spec schedules_for_stop(Plug.Conn.t(), map) :: Plug.Conn.t()
  def schedules_for_stop(conn, %{"stop_id" => stop_id} = params) do
    date = conn.assigns.date

    case Schedules.Repo.schedules_for_stop(stop_id, date: conn.assigns.date) do
      {:error, error} ->
        _ =
          Logger.error(
            "module=#{__MODULE__} fun=schedules_for_stop stop=#{stop_id} service_date=#{Date.to_string(date)} error=#{inspect(error)}"
          )

        DotcomWeb.ControllerHelpers.return_internal_error(conn)

      data ->
        schedules =
          data
          |> future_departures(params)
          |> omit_last_stop_departures(params)
          |> trim_response()

        case schedules do
          [%Schedule{} | _] ->
            json(conn, schedules)

          _ ->
            Logger.info(
              "module=#{__MODULE__} fun=schedules_for_stop stop=#{stop_id} data_length=#{length(data)} service_date=#{Date.to_string(date)} no_schedules_returned"
            )

            json(conn, [])
        end
    end
  end

  def cape_flyer(conn, _params) do
    redirect(conn, external: "https://capeflyer.com")
  end

  defp format_time(nil), do: "nil"

  defp format_time(time) do
    case Timex.format(time, "{h24}:{m}") do
      {:ok, time} -> time
      {:error, err} -> err
    end
  end

  defp trip_and_time_tuple(%Schedule{time: time, trip: trip}) do
    trip_id = if is_nil(trip), do: "nil", else: Map.get(trip, :id)
    time = format_time(time)
    {trip_id, time}
  end

  defp future_departures(schedules, %{"future_departures" => "true"} = params) do
    now = Util.now()
    # Only list schedules with time in the future. The "time" property might be
    # populated by the departure time or arrival time, depending on the mode
    {in_schedules, out_schedules} =
      Enum.split_with(schedules, fn %Schedule{time: t} ->
        not is_nil(t) and Util.time_is_greater_or_equal?(t, now)
      end)

    if in_schedules == [] and length(schedules) > 0 do
      # Why were so many schedules filtered out? Probably because they're in the
      # past. But let's log the last five, to uncover other possible issues.

      log_entries =
        Enum.map(
          out_schedules,
          &trip_and_time_tuple/1
        )
        |> Enum.take(-5)

      _ =
        Logger.info(
          "module=#{__MODULE__} fun=future_departures stop=#{params["stop_id"]} removed=#{inspect(log_entries)} time=#{format_time(now)}"
        )
    end

    in_schedules
  end

  defp future_departures(schedules, _), do: schedules

  defp omit_last_stop_departures(schedules, %{"last_stop_departures" => "false"}) do
    # Don't list schedules from the last stop
    Enum.reject(schedules, & &1.last_stop?)
  end

  defp omit_last_stop_departures(schedules, _), do: schedules

  defp trim_response(schedules) do
    schedules
    |> Enum.map(&Map.drop(&1, [:stop]))
    |> Enum.map(fn %Schedule{route: route} = schedule ->
      %Schedule{schedule | route: Map.take(route, [:id])}
    end)
  end
end
