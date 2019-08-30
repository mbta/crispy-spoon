defmodule Schedules.RepoCondensedTest do
  use ExUnit.Case
  use Timex
  import Schedules.RepoCondensed
  alias Schedules.ScheduleCondensed

  describe "by_route_ids/2" do
    test "can take a route/direction/sequence/date" do
      response =
        by_route_ids(
          ["CR-Lowell"],
          date: Util.service_date(),
          direction_id: 1,
          stop_sequences: "first"
        )

      assert response != []
      assert %ScheduleCondensed{} = List.first(response)
    end

    test "returns the parent station as the stop" do
      response =
        by_route_ids(
          ["Red"],
          date: Util.service_date(),
          direction_id: 0,
          stop_sequences: ["first"]
        )

      assert response != []
      assert %{stop_id: "place-alfcl"} = List.first(response)
    end

    test "filters by min_time when provided" do
      now = Util.now()

      before_now_fn = fn sched ->
        case DateTime.compare(sched.time, now) do
          :gt -> false
          :eq -> true
          :lt -> true
        end
      end

      unfiltered =
        by_route_ids(
          ["Red"],
          date: Util.service_date(),
          direction_id: 0
        )

      before_now = unfiltered |> Enum.filter(before_now_fn) |> Enum.count()
      assert before_now > 0

      filtered =
        by_route_ids(
          ["Red"],
          date: Util.service_date(),
          direction_id: 0,
          min_time: now
        )

      before_now = filtered |> Enum.filter(before_now_fn) |> Enum.count()
      assert before_now == 0
    end

    test "if we get an error from the API, returns an error tuple" do
      response =
        by_route_ids(
          ["CR-Lowell"],
          date: "1970-01-01",
          stop: "place-north"
        )

      assert {:error, _} = response
    end
  end
end
