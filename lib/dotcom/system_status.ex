defmodule Dotcom.SystemStatus do
  @moduledoc """
  Parent module for the system status feature
  """

  alias Dotcom.SystemStatus

  @doc """
  Returns a list of alerts that satisfy the following criteria:
  - They are for one of the subway or trolley lines (including Mattapan), and
  - They are either currently active, or will be later today
  """
  def subway_alerts_for_today() do
    subway_alerts_for_day(Timex.now())
  end

  defp subway_alerts_for_day(datetime) do
    [
      "Red",
      "Orange",
      "Blue",
      "Green-B",
      "Green-C",
      "Green-D",
      "Green-E",
      "Mattapan"
    ]
    |> Alerts.Repo.by_route_ids(datetime)
    |> SystemStatus.Alerts.for_day(datetime)
    |> SystemStatus.Alerts.filter_relevant()
  end
end
