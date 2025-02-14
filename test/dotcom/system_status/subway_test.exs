defmodule Dotcom.SystemStatus.SubwayTest do
  use ExUnit.Case, async: true
  doctest Dotcom.SystemStatus.Subway

  alias Dotcom.Alerts
  alias Dotcom.SystemStatus.Subway
  alias Test.Support.Factories.Alerts.Alert

  @lines_without_branches List.delete(Subway.lines(), "Green")

  describe "heavy rail groups" do
    test "when there are no alerts, lists each line as normal" do
      # Exercise
      groups = Subway.subway_status([], time_today())

      # Verify
      Subway.lines()
      |> Enum.each(fn route_id ->
        statuses = groups |> status_entries_for(route_id)

        assert statuses |> Enum.map(& &1.status) == [:normal]
        assert statuses |> Enum.map(& &1.multiple) == [false]
      end)
    end

    test "when there's an alert for a heavy rail line, shows an entry for that line" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)
      time = time_today()
      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id, effect: effect)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      [status] =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.status)

      assert status == effect
    end

    test "when there's an alert for a heavy rail line, shows the entry with multiple: false" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)
      time = time_today()
      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id, effect: effect)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      [multiple] =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.multiple)

      assert multiple == false
    end

    test "when there's a current alert, sets the `time` to :current" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)
      time = time_today()

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      times =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(fn s -> s.time end)

      assert times == [:current]
    end

    test "when there's an alert for a heavy rail line, shows 'Normal Service' for the other lines" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)
      time = time_today()

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      @lines_without_branches
      |> List.delete(affected_route_id)
      |> Enum.each(fn route_id ->
        statuses =
          groups
          |> status_entries_for(route_id)
          |> Enum.map(fn s -> s.status end)

        assert statuses == [:normal]
      end)
    end

    test "shows future active time for alerts that will become active later in the day" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)

      time = time_today()
      alert_start_time = time_after(time)

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id)
        |> Alert.active_starting_at(alert_start_time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      times =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.time)

      assert times == [{:future, alert_start_time}]
    end

    test "shows entry for active alerts with no end time" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)

      time = time_today()
      effect = Faker.Util.pick(Alerts.service_impacting_effects())
      alert_start_time = time_before(time)

      alerts = [
        Alert.build(:alert_for_route,
          route_id: affected_route_id,
          effect: effect,
          active_period: [{alert_start_time, nil}]
        )
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      statuses =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.status)

      assert statuses == [effect]
    end

    test "shows a future time for alerts that have an expired active_period as well" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)

      time = time_today()
      alert_start_time = time_after(time)
      alert_end_time = time_after(alert_start_time)

      expired_alert_end_time = time_before(time)
      expired_alert_start_time = time_before(expired_alert_end_time)

      alerts = [
        Alert.build(:alert_for_route,
          route_id: affected_route_id,
          active_period: [
            {expired_alert_start_time, expired_alert_end_time},
            {alert_start_time, alert_end_time}
          ]
        )
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      times =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.time)

      assert times == [{:future, alert_start_time}]
    end

    test "shows multiple alerts for a given route, sorted alphabetically" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)

      time = time_today()

      # Sorted in reverse order in order to validate that the sorting
      # logic works
      [effect2, effect1] =
        Faker.Util.sample_uniq(2, fn -> Faker.Util.pick(Alerts.service_impacting_effects()) end)
        |> Enum.sort(:desc)

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id, effect: effect1)
        |> Alert.active_during(time),
        Alert.build(:alert_for_route, route_id: affected_route_id, effect: effect2)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      statuses =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.status)

      assert statuses == [effect1, effect2]
    end

    test "sorts current alerts ahead of future ones" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)

      time = time_today()

      future_alert_start_time = time_after(time)

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id)
        |> Alert.active_starting_at(future_alert_start_time),
        Alert.build(:alert_for_route, route_id: affected_route_id)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      times =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.time)

      assert times == [:current, {:future, future_alert_start_time}]
    end

    test "consolidates current alerts if they have the same effect" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)

      time = time_today()

      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id, effect: effect)
        |> Alert.active_during(time),
        Alert.build(:alert_for_route, route_id: affected_route_id, effect: effect)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      multiples =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.multiple)

      assert multiples == [true]
    end

    test "consolidates future alerts if they have the same effect and time" do
      # Setup
      affected_route_id = Faker.Util.pick(@lines_without_branches)

      time = time_today()
      start_time = time_after(time)

      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_route_id, effect: effect)
        |> Alert.active_starting_at(start_time),
        Alert.build(:alert_for_route, route_id: affected_route_id, effect: effect)
        |> Alert.active_starting_at(start_time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      multiples =
        groups
        |> status_entries_for(affected_route_id)
        |> Enum.map(& &1.multiple)

      assert multiples == [true]
    end
  end

  describe "green line groups" do
    test "combines all green line branches into a single one if they have the same alerts" do
      # Setup
      time = time_today()

      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts =
        [
          Alert.build(:alert_for_routes, route_ids: GreenLine.branch_ids(), effect: effect)
          |> Alert.active_during(time)
        ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      statuses =
        groups
        |> status_entries_for("Green")
        |> Enum.map(& &1.status)

      assert statuses == [effect]
    end

    test "splits separate branches of the green line out as sub_routes if some have alerts and others don't" do
      # Setup
      affected_branch_id = Faker.Util.pick(GreenLine.branch_ids())

      time = time_today()
      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_branch_id, effect: effect)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      statuses =
        groups
        |> status_entries_for("Green", [affected_branch_id])
        |> Enum.map(& &1.status)

      assert statuses == [effect]
    end

    test "includes an 'Normal Service' entry for non-affected green line branches" do
      # Setup
      affected_branch_id = Faker.Util.pick(GreenLine.branch_ids())

      time = time_today()
      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_branch_id, effect: effect)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      normal_branch_ids = GreenLine.branch_ids() |> List.delete(affected_branch_id)

      statuses =
        groups
        |> status_entries_for("Green", normal_branch_ids)
        |> Enum.map(& &1.status)

      assert statuses == [:normal]
    end

    test "sorts alerts ahead of 'Normal Service'" do
      # Setup
      affected_branch_id = Faker.Util.pick(GreenLine.branch_ids())

      time = time_today()
      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_branch_id, effect: effect)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      normal_branch_ids = GreenLine.branch_ids() |> List.delete(affected_branch_id)

      branch_ids =
        groups
        |> Map.fetch!("Green")
        |> Enum.map(& &1.branch_ids)

      assert branch_ids == [
               [affected_branch_id],
               normal_branch_ids
             ]
    end

    test "sorts branches that do have alerts lexically by branch ID" do
      # Setup
      [affected_branch_id1, affected_branch_id2] =
        Faker.Util.sample_uniq(2, fn -> Faker.Util.pick(GreenLine.branch_ids()) end)

      time = time_today()

      [effect1, effect2] =
        Faker.Util.sample_uniq(2, fn -> Faker.Util.pick(Alerts.service_impacting_effects()) end)

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_branch_id1, effect: effect1)
        |> Alert.active_during(time),
        Alert.build(:alert_for_route, route_id: affected_branch_id2, effect: effect2)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      affected_branch_ids =
        groups
        |> Map.fetch!("Green")
        |> Enum.flat_map(& &1.branch_ids)
        |> Enum.take(2)

      assert affected_branch_ids == Enum.sort([affected_branch_id1, affected_branch_id2])
    end

    test "groups by green-line branch first, and by effect second" do
      # Setup
      affected_branch_id = Faker.Util.pick(GreenLine.branch_ids())

      time = time_today()

      [whole_line_effect, branch_effect] =
        Faker.Util.sample_uniq(2, fn -> Faker.Util.pick(Alerts.service_impacting_effects()) end)

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_branch_id, effect: branch_effect)
        |> Alert.active_during(time),
        Alert.build(:alert_for_routes,
          route_ids: GreenLine.branch_ids(),
          effect: whole_line_effect
        )
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      [whole_line_statuses, branch_statuses] =
        groups
        |> Map.fetch!("Green")

      assert whole_line_statuses |> Map.fetch!(:branch_ids) == []

      assert whole_line_statuses.status_entries |> Enum.map(& &1.status) == [
               whole_line_effect
             ]

      assert branch_statuses |> Map.fetch!(:branch_ids) == [affected_branch_id]
      assert branch_statuses.status_entries |> Enum.map(& &1.status) == [branch_effect]
    end

    test "consolidates green line alerts with the same branches and effects" do
      # Setup
      affected_branch_id = Faker.Util.pick(GreenLine.branch_ids())

      time = time_today()

      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_branch_id, effect: effect)
        |> Alert.active_during(time),
        Alert.build(:alert_for_route, route_id: affected_branch_id, effect: effect)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      statuses =
        groups
        |> status_entries_for("Green", [affected_branch_id])
        |> Enum.map(& &1.multiple)

      assert statuses == [true]
    end

    test "shows multiple alerts for a given branch, sorted alphabetically" do
      # Setup
      affected_branch_id = Faker.Util.pick(GreenLine.branch_ids())

      time = time_today()

      # Sorted in reverse order in order to validate that the sorting
      # logic works
      [effect2, effect1] =
        Faker.Util.sample_uniq(2, fn -> Faker.Util.pick(Alerts.service_impacting_effects()) end)
        |> Enum.sort(:desc)

      alerts = [
        Alert.build(:alert_for_route, route_id: affected_branch_id, effect: effect1)
        |> Alert.active_during(time),
        Alert.build(:alert_for_route, route_id: affected_branch_id, effect: effect2)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      statuses =
        groups
        |> status_entries_for("Green", [affected_branch_id])
        |> Enum.map(& &1.status)

      assert statuses == [effect1, effect2]
    end
  end

  describe "red line groups" do
    test "does not include Mattapan as a branch of the red line if Mattapan doesn't have any alerts" do
      # Setup
      time = time_today()

      alerts = [
        Alert.build(:alert_for_route, route_id: "Red")
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      red_line_statuses = groups |> Map.fetch!("Red")

      refute red_line_statuses
             |> Enum.any?(fn
               %{branch_ids: ["Mattapan"]} -> true
               _ -> false
             end)
    end

    test "shows Mattapan as a branch of Red if it has an alert" do
      # Setup
      time = time_today()
      effect = Faker.Util.pick(Alerts.service_impacting_effects())

      alerts = [
        Alert.build(:alert_for_route, route_id: "Mattapan", effect: effect)
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      statuses =
        groups
        |> status_entries_for("Red", ["Mattapan"])
        |> Enum.map(& &1.status)

      assert statuses == [effect]
    end

    test "includes a 'Normal Service' entry for Red if Mattapan has an alert" do
      # Setup
      time = time_today()

      alerts = [
        Alert.build(:alert_for_route, route_id: "Mattapan")
        |> Alert.active_during(time)
      ]

      # Exercise
      groups = Subway.subway_status(alerts, time)

      # Verify
      statuses =
        groups
        |> status_entries_for("Red")
        |> Enum.map(& &1.status)

      assert statuses == [:normal]
    end
  end

  # Returns the statuses for the given route_id and branch_id
  # collection. If no branches are specified, then returns the group
  # for the given route_id with an empty branch_ids list.
  defp status_entries_for(groups, route_id, branch_ids \\ []) do
    groups
    |> Map.fetch!(route_id)
    |> Enum.find(&(&1.branch_ids == branch_ids))
    |> Map.get(:status_entries)
  end

  # Returns the beginning of the day in the Eastern time zone.
  defp beginning_of_day() do
    Timex.beginning_of_day(Timex.now("America/New_York"))
  end

  # Returns the end of the day in the Eastern time zone.
  defp end_of_day() do
    Timex.end_of_day(Timex.now("America/New_York"))
  end

  # Returns a random time during the day today.
  defp time_today() do
    between(beginning_of_day(), end_of_day())
  end

  # Returns a random time during the day today before the time provided.
  defp time_before(time) do
    between(beginning_of_day(), time)
  end

  # Returns a random time during the day today after the time provided.
  defp time_after(time) do
    between(time, end_of_day())
  end

  # Returns a random time between the times provided in the Eastern time zone.
  defp between(time1, time2) do
    Faker.DateTime.between(time1, time2) |> Timex.to_datetime("America/New_York")
  end
end
