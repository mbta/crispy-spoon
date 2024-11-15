defmodule Alerts.SortTest do
  use ExUnit.Case, async: true
  use Quixir

  import Alerts.Sort

  alias Alerts.Alert

  describe "sort/2" do
    test "sorts the notices by their updated at times (newest to oldest)" do
      # put them in the future
      date = Timex.today() |> Timex.shift(days: 1)

      ptest times: list(positive_int()) do
        # create alerts with a bunch of updated_at times
        alerts =
          for time <- times do
            dt = date |> Timex.shift(seconds: time)
            %Alert{id: inspect(make_ref()), updated_at: dt, active_period: [{nil, nil}]}
          end

        actual = sort(alerts, DateTime.utc_now())
        # reverse after ID sort so that the second reverse puts them in the
        # right order
        expected =
          alerts
          |> Enum.sort_by(& &1.id)
          |> Enum.reverse()
          |> Enum.sort_by(& &1.updated_at, &Timex.after?/2)

        assert actual == expected
      end
    end

    test "uses the passed in date for active periods" do
      alert_prototype = %Alert{
        effect: :snow_route,
        lifecycle: "Upcoming",
        severity: 7,
        updated_at: new_datetime("2017-06-01T12:00:00-05:00")
      }

      period_1 =
        {new_datetime("2017-06-10T08:00:00-05:00"), new_datetime("2017-06-12T22:00:00-05:00")}

      period_2 =
        {new_datetime("2017-06-04T08:00:00-05:00"), new_datetime("2017-06-06T22:00:00-05:00")}

      alert_1 =
        alert_prototype
        |> Map.put(:active_period, [period_1])
        |> Map.put(:id, 1)

      alert_2 =
        alert_prototype
        |> Map.put(:active_period, [period_2])
        |> Map.put(:id, 2)

      sorted_alerts = sort([alert_1, alert_2], new_datetime("2017-06-01T12:00:00-05:00"))
      assert sorted_alerts == [alert_2, alert_1]

      re_sorted_alerts = sort([alert_1, alert_2], new_datetime("2017-06-08T12:00:00-05:00"))
      assert re_sorted_alerts == [alert_1, alert_2]
    end

    test "prioritizes alerts over notices" do
      {:ok, now, _} = DateTime.from_iso8601("2018-04-03T11:00:00Z")
      period_1 = {Timex.shift(now, hours: -1), Timex.shift(now, hours: 1)}

      alert_prototype = %Alert{
        effect: :snow_route,
        lifecycle: "New",
        severity: 5,
        updated_at: Timex.shift(now, hours: -3),
        active_period: [period_1]
      }

      notice_1 = %{alert_prototype | severity: 3, effect: :access_issue, id: 1, priority: :low}
      notice_2 = %{alert_prototype | severity: 3, effect: :access_issue, id: 2, priority: :low}
      alert_1 = %{alert_prototype | severity: 5, effect: :snow_route, id: 3, priority: :high}
      alerts = [notice_1, alert_1, notice_2]

      sorted_effects =
        alerts
        |> Alerts.Sort.sort(now)
        |> Enum.map(& &1.effect)

      assert sorted_effects == [:snow_route, :access_issue, :access_issue]
    end

    test "prioritizes a high-severity, low-priority alert over vice versa" do
      {:ok, now, _} = DateTime.from_iso8601("2018-04-03T11:00:00Z")

      alert_prototype = %Alert{
        effect: :snow_route,
        lifecycle: "Upcoming",
        updated_at: new_datetime("2017-06-01T12:00:00-05:00")
      }

      high_severity_low_priority = %Alert{alert_prototype | priority: :low, severity: 7}
      low_severity_high_priority = %Alert{alert_prototype | priority: :high, severity: 6}
      alerts = [low_severity_high_priority, high_severity_low_priority]

      sorted_alerts =
        alerts
        |> Alerts.Sort.sort(now)

      assert sorted_alerts == [high_severity_low_priority, low_severity_high_priority]
    end

    def new_datetime(str) do
      Timex.parse!(str, "{ISO:Extended}")
    end
  end
end
