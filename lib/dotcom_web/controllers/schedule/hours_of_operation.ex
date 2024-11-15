defmodule DotcomWeb.ScheduleController.HoursOfOperation do
  import Plug.Conn, only: [assign: 3]

  alias Schedules.HoursOfOperation

  @behaviour Plug

  @impl true
  def init([]), do: []

  @impl true
  def call(%Plug.Conn{assigns: %{route: route}} = conn, _opts) when not is_nil(route) do
    route.id
    |> full_route_id
    |> Schedules.HoursOfOperation.hours_of_operation(conn.assigns.date, route.description)
    |> assign_hours(conn)
  end

  def call(conn, _opts) do
    conn
  end

  defp full_route_id("Green") do
    GreenLine.branch_ids()
  end

  defp full_route_id(route_id) do
    route_id
  end

  defp assign_hours(hours, conn) when hours == %HoursOfOperation{}, do: conn
  defp assign_hours(hours, conn), do: assign(conn, :hours_of_operation, hours)
end
