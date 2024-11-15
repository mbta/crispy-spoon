defmodule DotcomWeb.ScheduleController.Holidays do
  import Plug.Conn, only: [assign: 3]

  alias DotcomWeb.ViewHelpers

  @behaviour Plug

  @impl true
  def init(opts) do
    Keyword.merge(opts || [], holiday_limit: 3)
  end

  @impl true
  def call(%Plug.Conn{assigns: %{date: date}} = conn, opts) do
    holidays =
      date
      |> Holiday.Repo.following()
      |> Enum.take(opts[:holiday_limit])
      |> Enum.map(fn holiday ->
        Map.update!(holiday, :date, fn date -> ViewHelpers.format_full_date(date) end)
      end)

    conn
    |> assign(:holidays, holidays)
  end

  def call(conn, _opts) do
    conn
  end
end
