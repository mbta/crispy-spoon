defmodule DotcomWeb.Plugs.DateTime do
  @moduledoc """

  Assigns @date to the Conn based on the "date" param.  If the date param is
  invalid or missing, uses today's service date.

  """
  import Plug.Conn, only: [assign: 3]

  @behaviour Plug

  @impl true
  def init([]), do: [now_fn: &Util.now/0]

  @impl true
  def call(conn, now_fn: now_fn) do
    conn
    |> assign(:date_time, date_time(conn.params["date_time"], now_fn))
  end

  defp date_time(nil, now_fn) do
    now_fn.()
  end

  defp date_time(str, now_fn) when is_binary(str) do
    case Timex.parse(str, "{ISO:Extended}") do
      {:ok, value} -> Timex.to_datetime(value, "America/New_York")
      _ -> now_fn.()
    end
  end
end
