defmodule DotcomWeb.ScheduleController.Offset do
  @moduledoc """
  Assigns the offset parameter to determine which scheduled trips to show.
  """

  import Plug.Conn, only: [assign: 3]

  @behaviour Plug

  @impl true
  def init([]), do: []

  @impl true
  def call(conn, []) do
    offset = find_offset(conn.assigns.timetable_schedules, conn.assigns.date_time)
    assign(conn, :offset, offset)
  end

  # find the index of the
  defp find_offset(timetable_schedules, date_time) do
    timetable_schedules
    |> last_stop_schedules
    |> Enum.find_index(&Timex.after?(&1.time, date_time))
    |> Kernel.||(0)
  end

  defp last_stop_schedules(timetable_schedules) do
    timetable_schedules
    |> Enum.reverse()
    |> Enum.uniq_by(& &1.trip)
    |> Enum.reverse()
  end
end
