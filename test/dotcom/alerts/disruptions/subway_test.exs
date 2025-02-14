defmodule Dotcom.Alerts.Disruptions.SubwayTest do
  use ExUnit.Case

  import Dotcom.Alerts, only: [service_impacting_effects: 0]
  import Dotcom.Alerts.Disruptions.Subway

  import Dotcom.Utils.ServiceDateTime,
    only: [
      service_range_day: 0,
      service_range_later_this_week: 0,
      service_range_next_week: 0,
      service_range_after_next_week: 0
    ]

  import Mox

  alias Test.Support.Factories

  setup :verify_on_exit!

  setup _ do
    stub_with(Dotcom.Utils.DateTime.Mock, Dotcom.Utils.DateTime)

    :ok
  end

  describe "future_disruptions/0" do
    test "returns an empty map when there are no alerts" do
      expect(Alerts.Repo.Mock, :by_route_ids, fn _route_ids, _now ->
        []
      end)

      # Exercise/Verify
      assert %{} = future_disruptions()
    end

    test "returns alerts for later this week, next week, and after next week" do
      # Setup
      alert_today = service_range_day() |> disruption_alert()
      alert_later_this_week = service_range_later_this_week() |> disruption_alert()
      alert_next_week = service_range_next_week() |> disruption_alert()

      {alert_after_next_week_start, _} = service_range_after_next_week()

      alert_after_next_week =
        {alert_after_next_week_start, Timex.shift(alert_after_next_week_start, days: 1)}
        |> disruption_alert()

      expect(Alerts.Repo.Mock, :by_route_ids, fn _route_ids, _now ->
        [alert_today, alert_later_this_week, alert_next_week, alert_after_next_week]
      end)

      # Exercise/Verify
      assert %{
               later_this_week: [^alert_later_this_week],
               next_week: [^alert_next_week],
               after_next_week: [^alert_after_next_week]
             } = future_disruptions()
    end
  end

  describe "todays_disruptions/0" do
    test "returns an empty map when there are no alerts" do
      expect(Alerts.Repo.Mock, :by_route_ids, fn _route_ids, _now ->
        []
      end)

      # Exercise/Verify
      assert %{} = todays_disruptions()
    end

    test "returns alerts for today only" do
      # Setup
      alert_today = service_range_day() |> disruption_alert()
      alert_next_week = service_range_next_week() |> disruption_alert()

      expect(Alerts.Repo.Mock, :by_route_ids, fn _route_ids, _now ->
        [alert_today, alert_next_week]
      end)

      # Exercise/Verify
      assert %{today: [^alert_today]} = todays_disruptions()
    end
  end

  defp disruption_alert(active_period) do
    Factories.Alerts.Alert.build(:alert,
      active_period: [active_period],
      effect: service_impacting_effects() |> Faker.Util.pick()
    )
  end
end
