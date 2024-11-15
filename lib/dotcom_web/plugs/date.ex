defmodule DotcomWeb.Plugs.Date do
  @moduledoc """

  Assigns @date to the Conn based on the "date" param.  If the date param is
  invalid or missing, uses today's service date.

  """
  import Plug.Conn, only: [assign: 3]

  @behaviour Plug

  @impl true
  def init([]), do: [date_fn: &Util.service_date/0]

  @impl true
  def call(conn, date_fn: date_fn) do
    conn
    |> assign(:date, date(conn.params["date"], date_fn))
  end

  defp date(nil, date_fn) do
    date_fn.()
  end

  defp date(str, date_fn) when is_binary(str) do
    str
    |> Timex.parse("{ISOdate}")
    |> do_date(date_fn)
  end

  defp do_date({:ok, value}, date_fn) do
    if Timex.is_valid?(value) do
      Timex.to_date(value)
    else
      date_fn.()
    end
  end

  defp do_date(_, date_fn) do
    date_fn.()
  end
end
