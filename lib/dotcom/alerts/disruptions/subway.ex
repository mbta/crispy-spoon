defmodule Dotcom.Alerts.Disruptions.Subway do
  @moduledoc """
  Disruptions are alerts that have `service_impacting_effects` grouped by `service_range`.
  """

  import Dotcom.Alerts, only: [service_impacting_alert?: 1]
  import Dotcom.Routes, only: [subway_route_ids: 0]
  import Dotcom.Utils.ServiceDateTime, only: [service_range: 1]

  alias Dotcom.Utils

  @doc """
  Disruptions that occur any time after today's service range.
  """
  def future_disruptions() do
    disruption_groups() |> Map.take([:this_week, :next_week, :later])
  end

  @doc """
  Disruptions that occur during today's service range.
  """
  def todays_disruptions() do
    disruption_groups() |> Map.take([:today])
  end

  # Groups all disruption alerts by service range.
  #
  # 1. Gets all alerts for subway routes.
  # 2. Filters out non-service-impacting alerts
  # 3. Groups them according to service range.
  defp disruption_groups() do
    subway_route_ids()
    |> Alerts.Repo.by_route_ids(Utils.DateTime.now())
    |> Enum.filter(&service_impacting_alert?/1)
    |> Enum.reduce(%{}, &group_alerts/2)
  end

  # Looks at every active period for an alert and groups that alert by service range.
  defp group_alerts(alert, groups) do
    alert
    |> Map.get(:active_period)
    |> Enum.map(fn {start, stop} -> [service_range(start), service_range(stop)] end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.reduce(groups, fn service_range, groups ->
      Map.update(groups, service_range, [alert], &(&1 ++ [alert]))
    end)
  end
end
