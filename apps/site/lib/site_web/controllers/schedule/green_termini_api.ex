defmodule SiteWeb.ScheduleController.GreenTerminiApi do
  @moduledoc """
    API for retrieving the terminuses of each green line route
  """
  use SiteWeb, :controller

  alias SiteWeb.ScheduleController.Line.Helpers, as: LineHelpers

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(_conn, %{
  }) do
    GreenLine.branch_ids()
    |> Map.new(fn [k] -> {k, Map.values(List.last(Tuple.to_list(LineHelpers.get_route("Green-B"))).direction_destinations)} end)
  end
end
