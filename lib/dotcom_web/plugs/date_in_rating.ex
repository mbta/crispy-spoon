defmodule DotcomWeb.Plugs.DateInRating do
  @moduledoc """
  Plug to validate the given date as being in the current schedule rating.

  If the date is outside the current rating, then we redirect such that the
  date isn't in the URL anymore.
  """

  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init([]), do: [dates_fn: &Schedules.Repo.rating_dates/0]

  @impl Plug
  def call(%Conn{assigns: %{date: date}, query_params: %{"date" => _}} = conn, dates_fn: dates_fn) do
    in_rating? =
      case dates_fn.() do
        {start_date, end_date} ->
          Date.compare(start_date, date) != :gt and Date.compare(end_date, date) != :lt

        :error ->
          true
      end

    assign_date_in_rating(conn, in_rating?)
  end

  def call(%Conn{} = conn, _) do
    assign_date_in_rating(conn, true)
  end

  defp assign_date_in_rating(conn, in_rating?) do
    Plug.Conn.assign(conn, :date_in_rating?, in_rating?)
  end
end
