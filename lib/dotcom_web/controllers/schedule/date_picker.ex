defmodule DotcomWeb.ScheduleController.DatePicker do
  use Plug.Builder

  import UrlHelpers, only: [update_url: 2]

  alias Plug.Conn

  plug(:assign_date_select)
  plug(:build_calendar)

  @spec assign_date_select(Conn.t(), []) :: Conn.t()
  def assign_date_select(conn, []) do
    assign(conn, :date_select, show_datepicker?(conn))
  end

  @doc "If the date selector is open, build the calendar"
  @spec build_calendar(Conn.t(), []) :: Conn.t()
  def build_calendar(%Conn{assigns: %{date: date}} = conn, []) do
    shift = shift(conn)
    holidays = date |> Timex.shift(months: shift) |> Holiday.Repo.holidays_in_month()

    calendar =
      BuildCalendar.build(
        date,
        Util.service_date(),
        holidays,
        &update_url(conn, &1),
        shift: shift,
        end_date: Schedules.Repo.end_of_rating()
      )

    conn
    |> assign(:calendar, calendar)
  end

  @spec show_datepicker?(Conn.t()) :: boolean
  defp show_datepicker?(%Conn{query_params: %{"date_select" => "true"}}), do: true
  defp show_datepicker?(%Conn{}), do: false

  defp shift(%Conn{query_params: %{"shift" => str}}) do
    case Integer.parse(str) do
      {integer, ""} ->
        integer

      _ ->
        0
    end
  end

  defp shift(%Conn{}) do
    0
  end
end
