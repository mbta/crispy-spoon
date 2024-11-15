defmodule DotcomWeb.Plugs.YearMonth do
  @moduledoc """

  Assigns @year and @month to the Conn based on the corresponding query params, using @date as a fallback.

  """

  import Plug.Conn, only: [assign: 3]

  @behaviour Plug

  @impl true
  def init([]), do: []

  @impl true
  def call(%{query_params: query_params} = conn, _opts) do
    conn
    |> assign(:year, year(Map.get(query_params, "year"), conn.assigns.date.year))
    |> assign(:month, month(Map.get(query_params, "month"), conn.assigns.date.month))
  end

  def call(conn, _opts) do
    conn
    |> assign(:year, conn.assigns.date.year)
    |> assign(:month, conn.assigns.date.month)
  end

  defp year(y, current) when is_binary(y) do
    case Integer.parse(y) do
      {parsed_year, _} -> year(parsed_year, current)
      :error -> current
    end
  end

  defp year(y, current) when is_integer(y) do
    case Date.new(y, 1, 1) do
      {:ok, _date} -> y
      _ -> current
    end
  end

  defp year(_, current), do: current

  defp month(m, current) when is_binary(m) do
    case Integer.parse(m) do
      {parsed_month, _} -> month(parsed_month, current)
      :error -> current
    end
  end

  defp month(m, _current) when m in 1..12, do: m

  defp month(_, current), do: current
end
