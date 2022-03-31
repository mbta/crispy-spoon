defmodule SiteWeb.ScheduleController.GreenTerminiApi do
  @moduledoc """
    API for retrieving the terminuses of each green line route
  """
  use SiteWeb, :controller

  alias SiteWeb.ScheduleController.Line.Helpers, as: LineHelpers

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _) do
    direction_destinations =
      GreenLine.branch_ids()
      |> Map.new(fn k ->
        {k, Map.values(elem(LineHelpers.get_route(k), 1).direction_destinations)}
      end)

    json(conn, direction_destinations)
  end
end
