defmodule Dotcom.SystemStatus.GroupsTest do
  use ExUnit.Case, async: true
  doctest Dotcom.SystemStatus.Groups

  alias Dotcom.SystemStatus.Groups
  alias Test.Support.Factories.Alerts.Alert
  alias Test.Support.Factories.Alerts.InformedEntity
  alias Test.Support.Factories.Alerts.InformedEntitySet

  @all_rail_lines ["Blue", "Green", "Orange", "Red"]
  @green_line_branches ["Green-B", "Green-C", "Green-D", "Green-E"]
  @heavy_rail_lines ["Blue", "Orange", "Red"]

  @effects [:delay, :shuttle, :station_closure, :suspension]
  @singular_effect_descriptions %{
    delay: "Delays",
    shuttle: "Shuttle Buses",
    station_closure: "Station Closure",
    suspension: "Suspension"
  }
  @plural_effect_descriptions %{
    delay: "Delays",
    shuttle: "Shuttle Buses",
    station_closure: "Station Closures",
    suspension: "Suspensions"
  }

  describe "heavy rail groups" do
    test "lists the lines in a consistent sort order" do
      # Exercise
      groups = Groups.groups([], time_today())

      # Verify
      route_ids = groups |> Enum.map(fn group -> group.route_id end)
      assert route_ids == ["Blue", "Orange", "Red", "Green"]
    end

    test "when there are no alerts, lists each line as normal" do
      # Exercise
      groups = Groups.groups([], time_today())

      # Verify
      expected_statuses = [%{description: "Normal Service", time: nil}]

      @all_rail_lines
      |> Enum.each(fn route_id ->
        statuses = groups |> statuses_for(route_id)

        assert statuses == expected_statuses
      end)
    end

    test "when there's an alert for a heavy rail line, shows an entry for that line with a human-readable description" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)
      time = time_today()
      effect = Faker.Util.pick(@effects)
      alerts = [current_alert(route_id: affected_route_id, time: time, effect: effect)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      [description] =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.description)

      assert description == @singular_effect_descriptions[effect]
    end

    test "when there's a current alert, sets the `time` to nil" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)
      time = time_today()
      alerts = [current_alert(route_id: affected_route_id, time: time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      times =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(fn s -> s.time end)

      assert times == [nil]
    end

    test "when there's an alert for a heavy rail line, shows 'Normal Service' for the other lines" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)
      time = time_today()

      alerts = [current_alert(route_id: affected_route_id, time: time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      @heavy_rail_lines
      |> List.delete(affected_route_id)
      |> Enum.each(fn route_id ->
        descriptions =
          groups
          |> statuses_for(route_id)
          |> Enum.map(fn s -> s.description end)

        assert descriptions == ["Normal Service"]
      end)
    end

    test "shows future active time for alerts that will become active later in the day" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)

      time = time_today()
      alert_start_time = time_after(time)

      alerts = [future_alert(route_id: affected_route_id, start_time: alert_start_time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      times =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.time)

      assert times == [Util.kitchen_downcase_time(alert_start_time)]
    end

    test "shows entry for active alerts with no end time" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)

      time = time_today()
      effect = Faker.Util.pick(@effects)
      alert_start_time = time_before(time)

      alerts = [
        alert(
          route_id: affected_route_id,
          effect: effect,
          active_period: [{alert_start_time, nil}]
        )
      ]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      descriptions =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.description)

      assert descriptions == [@singular_effect_descriptions[effect]]
    end

    test "shows a future time for alerts that have an expired active_period as well" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)

      time = time_today()
      alert_start_time = time_after(time)
      alert_end_time = time_after(alert_start_time)

      expired_alert_end_time = time_before(time)
      expired_alert_start_time = time_before(expired_alert_end_time)

      alerts = [
        alert(
          route_id: affected_route_id,
          active_period: [
            {expired_alert_start_time, expired_alert_end_time},
            {alert_start_time, alert_end_time}
          ]
        )
      ]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      times =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.time)

      assert times == [Util.kitchen_downcase_time(alert_start_time)]
    end

    test "shows multiple alerts for a given route, sorted alphabetically" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)

      time = time_today()

      # Sorted in reverse order in order to validate that the sorting
      # logic works
      [effect2, effect1] =
        Faker.Util.sample_uniq(2, fn -> Faker.Util.pick(@effects) end) |> Enum.sort(:desc)

      alerts = [
        current_alert(route_id: affected_route_id, time: time, effect: effect1),
        current_alert(route_id: affected_route_id, time: time, effect: effect2)
      ]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      descriptions =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.description)

      assert descriptions == [
               @singular_effect_descriptions[effect1],
               @singular_effect_descriptions[effect2]
             ]
    end

    test "puts 'Now' text on current alerts when there are also future alerts, and sorts 'Now' first" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)

      time = time_today()

      future_alert_start_time = time_after(time)

      alerts = [
        future_alert(route_id: affected_route_id, start_time: future_alert_start_time),
        current_alert(route_id: affected_route_id, time: time)
      ]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      times =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.time)

      assert times == ["Now", Util.kitchen_downcase_time(future_alert_start_time)]
    end

    test "sorts future alerts by time, not lexically" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)

      # The first alert's start time will be between 2pm and
      # 9:59pm. The second's will be between 10pm and
      # 11:59pm. Lexically, the second alert would get sorted before
      # the first, but we want the first to get sorted before the
      # second.
      alert_1_start_time =
        between(
          Timex.shift(beginning_of_day(), hours: 14),
          Timex.shift(beginning_of_day(), hours: 22)
        )

      alert_2_start_time =
        between(
          Timex.shift(beginning_of_day(), hours: 22),
          Timex.shift(beginning_of_day(), hours: 24)
        )

      time = time_before(alert_1_start_time)

      alerts = [
        future_alert(route_id: affected_route_id, start_time: alert_1_start_time),
        future_alert(route_id: affected_route_id, start_time: alert_2_start_time)
      ]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      times =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.time)

      assert times == [
               Util.kitchen_downcase_time(alert_1_start_time),
               Util.kitchen_downcase_time(alert_2_start_time)
             ]
    end

    test "consolidates current alerts if they have the same effect" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)

      time = time_today()

      effect = Faker.Util.pick(@effects)

      alerts = [
        current_alert(route_id: affected_route_id, time: time, effect: effect),
        current_alert(route_id: affected_route_id, time: time, effect: effect)
      ]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify      
      descriptions =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.description)

      assert descriptions == [@plural_effect_descriptions[effect]]
    end

    test "consolidates future alerts if they have the same effect and time" do
      # Setup
      affected_route_id = Faker.Util.pick(@heavy_rail_lines)

      time = time_today()
      start_time = time_after(time)

      effect = Faker.Util.pick(@effects)

      alerts = [
        future_alert(route_id: affected_route_id, start_time: start_time, effect: effect),
        future_alert(route_id: affected_route_id, start_time: start_time, effect: effect)
      ]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify      
      descriptions =
        groups
        |> statuses_for(affected_route_id)
        |> Enum.map(& &1.description)

      assert descriptions == [@plural_effect_descriptions[effect]]
    end
  end

  describe "green line groups" do
    test "combines all green line branches into a single one if they have the same alerts" do
      # Setup
      time = time_today()

      effect = Faker.Util.pick(@effects)

      alerts =
        @green_line_branches
        |> Enum.map(fn route_id ->
          current_alert(route_id: route_id, time: time, effect: effect)
        end)

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      descriptions =
        groups
        |> statuses_for("Green")
        |> Enum.map(& &1.description)

      assert descriptions == [@singular_effect_descriptions[effect]]
    end

    test "splits separate branches of the green line out as sub_routes if some have alerts and others don't" do
      # Setup
      affected_branch_id = Faker.Util.pick(@green_line_branches)

      time = time_today()
      effect = Faker.Util.pick(@effects)

      alerts = [current_alert(route_id: affected_branch_id, effect: effect, time: time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      descriptions =
        groups
        |> statuses_for("Green", [affected_branch_id])
        |> Enum.map(& &1.description)

      assert descriptions == [@singular_effect_descriptions[effect]]
    end

    test "includes an 'Normal Service' entry for non-affected green line branches" do
      # Setup
      affected_branch_id = Faker.Util.pick(@green_line_branches)

      time = time_today()
      effect = Faker.Util.pick(@effects)

      alerts = [current_alert(route_id: affected_branch_id, effect: effect, time: time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      normal_branch_ids = @green_line_branches |> List.delete(affected_branch_id)

      descriptions =
        groups
        |> statuses_for("Green", normal_branch_ids)
        |> Enum.map(& &1.description)

      assert descriptions == ["Normal Service"]
    end

    test "sorts alerts ahead of 'Normal Service'" do
      # Setup
      affected_branch_id = Faker.Util.pick(@green_line_branches)

      time = time_today()
      effect = Faker.Util.pick(@effects)

      alerts = [current_alert(route_id: affected_branch_id, effect: effect, time: time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      normal_branch_ids = @green_line_branches |> List.delete(affected_branch_id)

      branch_ids =
        groups
        |> Enum.find(&(&1.route_id == "Green"))
        |> then(& &1.branches_with_statuses)
        |> Enum.map(& &1.branch_ids)

      assert branch_ids == [
               [affected_branch_id],
               normal_branch_ids
             ]
    end

    test "sorts branches that do have alerts lexically by branch ID" do
      # Setup
      [affected_branch_id1, affected_branch_id2] =
        Faker.Util.sample_uniq(2, fn -> Faker.Util.pick(@green_line_branches) end)

      time = time_today()
      [effect1, effect2] = Faker.Util.sample_uniq(2, fn -> Faker.Util.pick(@effects) end)

      alerts = [
        current_alert(route_id: affected_branch_id1, effect: effect1, time: time),
        current_alert(route_id: affected_branch_id2, effect: effect2, time: time)
      ]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      affected_branch_ids =
        groups
        |> Enum.find(&(&1.route_id == "Green"))
        |> then(& &1.branches_with_statuses)
        |> Enum.flat_map(& &1.branch_ids)
        |> Enum.take(2)

      assert affected_branch_ids == Enum.sort([affected_branch_id1, affected_branch_id2])
    end
  end

  describe "red line groups" do
    test "does not include Mattapan as a branch of the red line if Mattapan doesn't have any alerts" do
      # Setup
      time = time_today()

      alerts = [current_alert(route_id: "Red", time: time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      red_line_statuses = groups |> Enum.find(&(&1.route_id == "Red"))

      refute red_line_statuses.branches_with_statuses
             |> Enum.any?(fn
               %{branch_ids: ["Mattapan"]} -> true
               _ -> false
             end)
    end

    test "shows Mattapan as a branch of Red if it has an alert" do
      # Setup
      time = time_today()
      effect = Faker.Util.pick(@effects)

      alerts = [current_alert(route_id: "Mattapan", effect: effect, time: time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      descriptions =
        groups
        |> statuses_for("Red", ["Mattapan"])
        |> Enum.map(& &1.description)

      assert descriptions == [@singular_effect_descriptions[effect]]
    end

    test "includes a 'Normal Service' entry for Red if Mattapan has an alert" do
      # Setup
      time = time_today()

      alerts = [current_alert(route_id: "Mattapan", time: time)]

      # Exercise
      groups = Groups.groups(alerts, time)

      # Verify
      descriptions =
        groups
        |> statuses_for("Red")
        |> Enum.map(& &1.description)

      assert descriptions == ["Normal Service"]
    end
  end

  # Returns the statuses for the given route_id and branch_id
  # collection. If no branches are specified, then returns the group
  # for the given route_id with an empty branch_ids list.
  defp statuses_for(groups, route_id, branch_ids \\ []) do
    groups
    |> Enum.find(&(&1.route_id == route_id))
    |> Map.fetch!(:branches_with_statuses)
    |> Enum.find(&(&1.branch_ids == branch_ids))
    |> Map.get(:statuses)
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

  # Returns a random alert that will be active at the time given by
  # the required `:time` opt.
  #
  # Required opts:
  #  - route_id
  #  - time
  #
  # Optional opts:
  #  - effect (default behavior is to choose an effect at random)
  defp current_alert(opts) do
    {time, opts} = opts |> Keyword.pop!(:time)

    start_time = time_before(time)
    end_time = time_after(time)

    opts
    |> Keyword.put_new(:active_period, [{start_time, end_time}])
    |> alert()
  end

  # Returns a random alert whose active_period starts at the provided
  # `:start_time` opt.
  #
  # Required opts:
  #  - route_id
  #  - start_time
  #
  # Optional opts:
  #  - effect (default behavior is to choose an effect at random)
  defp future_alert(opts) do
    {start_time, opts} = opts |> Keyword.pop!(:start_time)

    opts
    |> Keyword.put_new(:active_period, [{start_time, time_after(start_time)}])
    |> alert()
  end

  # Returns a random alert for the given `:route_id` and
  # `:active_period` opts.
  #
  # Required opts:
  #  - route_id
  #  - active_period (Note that this is an array)
  #
  # Optional opts:
  #  - effect (default behavior is to choose an effect at random)
  defp alert(opts) do
    route_id = opts |> Keyword.fetch!(:route_id)
    effect = opts[:effect] || Faker.Util.pick(@effects)
    active_period = opts |> Keyword.fetch!(:active_period)

    Alert.build(:alert,
      effect: effect,
      informed_entity:
        InformedEntitySet.build(:informed_entity_set,
          route: route_id,
          entities: [
            InformedEntity.build(:informed_entity, route: route_id)
          ]
        ),
      active_period: active_period
    )
  end
end
