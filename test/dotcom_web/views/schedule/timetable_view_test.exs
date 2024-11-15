defmodule DotcomWeb.Schedule.TimetableViewTest do
  use ExUnit.Case, async: true

  import DotcomWeb.ScheduleView.Timetable
  import Phoenix.ConnTest, only: [build_conn: 0]
  import Phoenix.HTML, only: [safe_to_string: 1]

  alias Schedules.Schedule

  describe "stop_tooltip/2" do
    @expected_flag "Flag Stop"
    @expected_delayed "Early Departure Stop"
    @expected_track_change "Train scheduled to board from Track 1 at Back Bay"

    test "returns nil when there are no matches" do
      assert nil == stop_tooltip(%Schedule{}, nil)
    end

    test "returns only a flag stop" do
      actual = stop_tooltip(%Schedule{flag?: true}, nil)
      assert actual =~ @expected_flag
      refute actual =~ @expected_delayed
    end

    test "returns only an early departure" do
      actual = stop_tooltip(%Schedule{early_departure?: true}, nil)
      refute actual =~ @expected_flag
      assert actual =~ @expected_delayed
    end

    test "returns only a track change" do
      actual =
        stop_tooltip(%Schedule{stop: %Stops.Stop{id: "1", name: "Back Bay"}}, %Stops.Stop{
          id: "2",
          platform_name: "Track 1",
          platform_code: "1"
        })

      assert actual =~ @expected_track_change
    end

    test "returns flag stop and track change" do
      actual =
        stop_tooltip(
          %Schedule{flag?: true, stop: %Stops.Stop{id: "1", name: "Back Bay"}},
          %Stops.Stop{
            id: "2",
            platform_name: "Track 1",
            platform_code: "1"
          }
        )

      assert actual =~ @expected_track_change
      assert actual =~ @expected_flag
    end
  end

  describe "_timetable.html" do
    setup do
      conn = %{build_conn() | query_params: %{}}
      date = ~D[2018-01-01]
      headsigns = %{0 => ["Headsign"]}
      offset = 0
      route = %Routes.Route{direction_destinations: %{0 => "End"}}
      direction_id = 0
      origin = destination = nil
      alerts = []

      header_stops = [
        {%Stops.Stop{id: "stop", name: "Stop"}, 0}
      ]

      vehicle_tooltips = vehicle_locations = trip_messages = trip_schedules = %{}
      show_date_select? = false

      assigns = [
        conn: conn,
        channel: "fakeId",
        vehicle_schedules: [],
        prior_stops: [],
        date: date,
        headsigns: headsigns,
        route: route,
        direction_id: direction_id,
        origin: origin,
        destination: destination,
        alerts: alerts,
        offset: offset,
        show_date_select?: show_date_select?,
        header_stops: header_stops,
        vehicle_tooltips: vehicle_tooltips,
        vehicle_locations: vehicle_locations,
        trip_messages: trip_messages,
        trip_schedules: trip_schedules,
        track_changes: %{},
        date_time: ~N[2017-03-01T07:29:00],
        direction_name: "Southeastbound",
        formatted_date: "March 1, 2017"
      ]

      {:ok, %{assigns: assigns}}
    end

    test "does not render the earlier/later train columns when there is one schedule", %{
      assigns: assigns
    } do
      trip = %Schedules.Trip{name: "name"}

      header_schedules = [
        %Schedules.Schedule{trip: trip}
      ]

      assigns = Keyword.put(assigns, :header_schedules, header_schedules)
      rendered = DotcomWeb.ScheduleView.render("_timetable.html", assigns)
      refute safe_to_string(rendered) =~ "Earlier Trains"
      refute safe_to_string(rendered) =~ "Later Trains"
    end

    test "renders the earlier/later train columns when there are two or more schedules", %{
      assigns: assigns
    } do
      trip = %Schedules.Trip{name: "name"}

      header_schedules = [
        %Schedules.Schedule{trip: trip},
        %Schedules.Schedule{trip: trip}
      ]

      assigns = Keyword.put(assigns, :header_schedules, header_schedules)
      rendered = DotcomWeb.ScheduleView.render("_timetable.html", assigns)
      assert safe_to_string(rendered) =~ "Earlier Trains"
      assert safe_to_string(rendered) =~ "Later Trains"
    end

    test "should show the track change information if present", %{assigns: assigns} do
      trip = %Schedules.Trip{name: "Test Trip", id: "Test-Trip-ID"}

      original_stop = %Stops.Stop{
        id: "Test-Stop-ID",
        name: "Stop",
        platform_name: "Original Track"
      }

      new_platform_stop = %Stops.Stop{platform_name: "New Track"}

      track_changes = %{{"Test-Trip-ID", "Test-Stop-ID"} => new_platform_stop}
      header_schedules = [%Schedules.Schedule{trip: trip}]

      trip_schedules = %{
        {"Test-Trip-ID", "Test-Stop-ID"} => %Schedules.Schedule{
          stop: original_stop,
          time: Timex.now(),
          trip: trip
        }
      }

      assigns =
        Keyword.merge(assigns,
          header_schedules: header_schedules,
          track_changes: track_changes,
          header_stops: [{original_stop, 0}],
          trip_schedules: trip_schedules
        )

      rendered = DotcomWeb.ScheduleView.render("_timetable.html", assigns)
      assert safe_to_string(rendered) =~ "New Track"
    end
  end
end
