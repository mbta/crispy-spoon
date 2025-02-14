defmodule DotcomWeb.AlertViewTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Timex

  import Phoenix.HTML, only: [safe_to_string: 1, raw: 1]
  import DotcomWeb.AlertView
  alias Alerts.{Alert, Banner, InformedEntity, InformedEntitySet}
  alias Routes.Route
  alias Stops.Stop

  @route %Routes.Route{type: 2, id: "route_id", name: "Name"}
  @now Util.to_local_time(~N[2018-01-15T12:00:00])

  describe "effect_name/1" do
    test "returns the effect name for new alerts" do
      assert "Delay" == effect_name(%Alert{effect: :delay, lifecycle: :new})
    end

    test "includes the lifecycle for alerts" do
      assert "Shuttle" ==
               %Alert{effect: :shuttle, lifecycle: :upcoming}
               |> effect_name
               |> IO.iodata_to_binary()
    end
  end

  describe "alert_updated/1" do
    test "returns the relative offset based on our timezone" do
      now = ~N[2016-10-05T00:02:03]
      date = ~D[2016-10-05]
      alert = %Alert{updated_at: now}

      expected = "Updated: Today at 12:02 AM"
      actual = alert |> alert_updated(date) |> :erlang.iolist_to_binary()
      assert actual == expected
    end

    test "alerts from further in the past use a date" do
      now = ~N[2016-10-05T00:02:03]
      date = ~D[2016-10-06]

      alert = %Alert{updated_at: now}

      expected = "Updated: 10/5/2016 12:02 AM"
      actual = alert |> alert_updated(date) |> :erlang.iolist_to_binary()
      assert actual == expected
    end
  end

  describe "format_alert_description/1" do
    test "escapes existing HTML" do
      expected = {:safe, "&lt;br&gt;"}
      actual = format_alert_description("<br>")

      assert expected == actual
    end

    test "replaces newlines with breaks" do
      expected = {:safe, "hi<br />there"}
      actual = format_alert_description("hi\nthere")

      assert expected == actual
    end

    test "combines multiple newlines" do
      expected = {:safe, "hi<br />there"}
      actual = format_alert_description("hi\n\n\nthere")

      assert expected == actual
    end

    test "combines multiple Windows newlines" do
      expected = {:safe, "hi<br />there"}
      actual = format_alert_description("hi\r\n\r\nthere")

      assert expected == actual
    end

    test "<strong>ifies a header" do
      expected = {:safe, "hi<br /><strong>Header:</strong><br />7:30"}
      actual = format_alert_description("hi\nHeader:\n7:30")

      assert expected == actual
    end

    test "<strong>ifies a starting long header" do
      expected = {:safe, "<strong>Long Header:</strong><br />7:30"}
      actual = format_alert_description("Long Header:\n7:30")

      assert expected == actual
    end

    test "linkifies a URL" do
      expected = raw(~s(before <a target="_blank" href="http://mbta.com">MBTA.com</a> after))

      actual = format_alert_description("before http://mbta.com after")

      assert expected == actual
    end
  end

  describe "replace_urls_with_links/1" do
    test "does not include a period at the end of the URL" do
      expected = raw(~s(<a target="_blank" href="http://mbta.com/foo/bar">MBTA.com/foo/bar</a>.))

      actual = replace_urls_with_links("http://mbta.com/foo/bar.")

      assert expected == actual
    end

    test "can replace multiple URLs" do
      expected = raw(~s(<a target="_blank" href="http://one.com">one.com</a> \
<a target="_blank" href="https://two.net">two.net</a>))
      actual = replace_urls_with_links("http://one.com https://two.net")

      assert expected == actual
    end

    test "adds http:// to the URL if it's missing" do
      expected = raw(~s(<a target="_blank" href="http://http.com">http.com</a>))
      actual = replace_urls_with_links("http.com")

      assert expected == actual
    end

    test "adds https:// to the URL if it's mbta.com" do
      expected = raw(~s(<a target="_blank" href="https://mbta.com/GLwork">MBTA.com/GLwork</a>))
      actual = replace_urls_with_links("mbta.com/GLwork")

      assert expected == actual
    end

    test "does not link short TLDs" do
      expected = raw("a.m.")
      actual = replace_urls_with_links("a.m.")
      assert expected == actual
    end

    test "does not link emails" do
      expected = raw("test@mbta.com")
      actual = replace_urls_with_links("test@mbta.com")
      assert expected == actual
    end
  end

  describe "group.html" do
    test "text for no current alerts and show_empty set to false (default)" do
      response =
        render(
          "group.html",
          alerts: [],
          timeframe: :current,
          route: @route
        )

      text = safe_to_string(response)
      refute text =~ "There are no alerts"
    end

    test "text for no current alerts and show_empty? set for a route" do
      response =
        group(
          alerts: [],
          route: @route,
          stop?: false,
          show_empty?: true,
          timeframe: :current
        )

      text = safe_to_string(response)

      assert text =~ "Service is running as expected on the Name. There are no current alerts."
    end

    test "text for no alerts of any type but show_empty? set for a stop" do
      response =
        group(
          alerts: [],
          route: @route,
          stop?: true,
          show_empty?: true
        )

      text = safe_to_string(response)
      assert text =~ "There are no alerts on the Name at this time."
    end

    test "text for an CR alert which is blocking the timetable (but has a PDF available)" do
      alert = %Alerts.Alert{
        header: "Blocked timetable. #{Dotcom.TimetableBlocking.pdf_available_text()}",
        url: "https://www.mbta.com/pdf-timetable",
        updated_at: DateTime.utc_now()
      }

      response =
        group(
          alerts: [alert],
          route: @route,
          stop?: false,
          show_empty?: false,
          date_time: DateTime.utc_now()
        )

      text = safe_to_string(response)

      refute text =~ Dotcom.TimetableBlocking.pdf_available_text()
      assert text =~ ~s["https://www.mbta.com/pdf-timetable"]
      assert text =~ ">View PDF Timetable</a>"
    end

    test "shows a blocking alert even if it's low priority" do
      alert =
        Alerts.Alert.new(
          header: "Blocked timetable. #{Dotcom.TimetableBlocking.no_pdf_text()}",
          priority: :low,
          updated_at: DateTime.utc_now(),
          informed_entity: [%Alerts.InformedEntity{route: @route.id}],
          active_period: [{~U[2025-01-01T00:00:00Z], nil}]
        )

      response =
        group(
          alerts: [alert],
          route: @route,
          date_time: DateTime.utc_now(),
          priority_filter: :high,
          always_show: [alert]
        )

      text = safe_to_string(response)
      assert text =~ "Blocked timetable."
    end

    test "shows a blocking alert only once" do
      alert =
        Alerts.Alert.new(
          header: "Blocked timetable. #{Dotcom.TimetableBlocking.no_pdf_text()}",
          priority: :low,
          updated_at: DateTime.utc_now(),
          informed_entity: [%Alerts.InformedEntity{route: @route.id}],
          active_period: [{~U[2025-01-01T00:00:00Z], nil}]
        )

      response =
        group(
          alerts: [alert],
          route: @route,
          date_time: DateTime.utc_now(),
          always_show: [alert]
        )

      text = safe_to_string(response)
      # only one copy of the alert
      assert [_] = Regex.scan(~r/Blocked timetable/, text)
    end

    test "does not show a blocking alert on the wrong date" do
      alert =
        Alerts.Alert.new(
          header: "Blocked timetable. #{Dotcom.TimetableBlocking.no_pdf_text()}",
          priority: :low,
          updated_at: DateTime.utc_now(),
          informed_entity: [%Alerts.InformedEntity{route: @route.id}],
          active_period: [{~U[2025-02-02T00:00:00Z], nil}]
        )

      response =
        group(
          alerts: [alert],
          route: @route,
          date_time: DateTime.utc_now(),
          priority_filter: :high,
          always_show: []
        )

      assert response == ""
    end
  end

  describe "no_alerts_message/3" do
    test "reports service as running as expected when timeframe is current for routes" do
      msg = no_alerts_message(%{name: "Route", id: 2}, false, :current)

      assert IO.iodata_to_binary(msg) =~
               "Service is running as expected on the Route. There are no current alerts."
    end

    test "reports service as running as expected when timeframe is current for stops" do
      msg = no_alerts_message(%{name: "Stop", id: 1}, true, :current)

      assert IO.iodata_to_binary(msg) =~ "There are no current alerts at Stop."
    end

    test "reports no upcoming alerts for a route" do
      msg = no_alerts_message(%{name: "Route", id: 1}, false, :upcoming)
      assert IO.iodata_to_binary(msg) =~ "There are no planned alerts for the Route at this time."
    end

    test "reports no upcoming alerts at a stop" do
      msg = no_alerts_message(%{name: "Stop", id: 1}, true, :upcoming)
      assert IO.iodata_to_binary(msg) =~ "There are no planned alerts at Stop at this time."
    end
  end

  describe "location_name/2" do
    test "creates a location name with prefix for a route" do
      assert IO.iodata_to_binary(location_name(%{name: "Route"}, false)) == " on the Route"
    end

    test "creates a location name with a prefix for a stop" do
      assert IO.iodata_to_binary(location_name(%{name: "Stop"}, true)) == " at Stop"
    end
  end

  describe "format_alerts_timeframe" do
    test "formats :upcoming to planned" do
      assert format_alerts_timeframe(:upcoming) == "planned"
    end

    test "if alerts_timeframe isn't set, returns empty string" do
      assert format_alerts_timeframe(nil) == ""
    end

    test "converts an atom to a string" do
      assert format_alerts_timeframe(:current) == "current"
    end
  end

  describe "empty_message_for_timeframe/2" do
    test "returns a generic empty message if a timeframe isn't provided" do
      assert IO.iodata_to_binary(empty_message_for_timeframe(nil, " for the Route")) ==
               "There are no alerts for the Route at this time."
    end

    test "formats an empty message for current alerts" do
      assert IO.iodata_to_binary(empty_message_for_timeframe(:upcoming, " at this Location")) ==
               "There are no planned alerts at this Location at this time."
    end
  end

  describe "_item.html" do
    @alert %Alert{
      effect: :access_issue,
      updated_at: ~D[2017-03-01],
      header: "Alert Header",
      description: "description"
    }
    @date_time ~N[2017-03-01T07:29:00]
    @active_period [{Timex.shift(@now, days: -8), Timex.shift(@now, days: 8)}]

    test "Displays expansion control if alert has description" do
      response = render("_item.html", alert: @alert, date_time: @date_time)
      assert safe_to_string(response) =~ "c-alert-item__caret--up"
    end

    test "Does not display expansion control if description is nil" do
      response = render("_item.html", alert: %{@alert | description: nil}, date_time: @date_time)

      refute safe_to_string(response) =~ "c-alert-item__caret--up"
    end

    test "Icons and labels are displayed for shuttle today" do
      response =
        "_item.html"
        |> render(
          alert: %Alert{
            effect: :shuttle,
            lifecycle: :ongoing,
            severity: 7,
            priority: :high
          },
          date_time: @now
        )
        |> safe_to_string()

      assert response =~ "c-svg__icon-shuttle-default"
    end

    test "Icons and labels are displayed for delay" do
      response =
        "_item.html"
        |> render(
          alert: %Alert{
            effect: :delay,
            priority: :high
          },
          date_time: @now
        )
        |> safe_to_string()

      assert response =~ "c-svg__icon-alerts-triangle"
    end

    test "Icons and labels are displayed for snow route" do
      response =
        "_item.html"
        |> render(
          alert: %Alert{
            effect: :snow_route,
            lifecycle: :ongoing,
            severity: 7,
            priority: :high
          },
          date_time: @now
        )
        |> safe_to_string()

      assert response =~ "c-svg__icon-snow-default"
      assert response =~ "Snow Route"
    end

    test "Icons and labels are displayed for cancellation" do
      response =
        render(
          "_item.html",
          alert: %Alert{
            effect: :cancellation,
            active_period: @active_period,
            priority: :high
          },
          date_time: @now
        )

      assert safe_to_string(response) =~ "c-svg__icon-cancelled-default"
    end

    test "No icon for future cancellation" do
      response =
        "_item.html"
        |> render(
          alert: %Alert{
            effect: :cancellation,
            active_period: @active_period,
            lifecycle: :upcoming,
            priority: :low
          },
          date_time: @date_time
        )
        |> safe_to_string()

      refute response =~ "c-svg__icon"
      assert response =~ "Cancellation"
    end
  end

  describe "show_systemwide_alert?/1" do
    setup do
      banner_template = "_alert_announcement.html"

      alert_banner = %Banner{
        id: "123",
        title: "All service may experience delays due to snow",
        url: "https://mbta.com/guides/winter-guide",
        effect: :delay,
        severity: 5,
        informed_entity_set:
          InformedEntitySet.new([
            %InformedEntity{
              activities: MapSet.new([:board, :exit, :ride]),
              direction_id: nil,
              route: nil,
              route_type: 0,
              stop: nil,
              trip: nil
            },
            %InformedEntity{
              activities: MapSet.new([:board, :exit, :ride]),
              direction_id: nil,
              route: nil,
              route_type: 1,
              stop: nil,
              trip: nil
            }
          ])
      }

      assigns = %{
        banner_template: banner_template,
        alert_banner: alert_banner
      }

      %{assigns: assigns}
    end

    test "tests whether any informed entities on the alert_banenr match a list of route types", %{
      assigns: assigns
    } do
      matching_assigns = Map.merge(assigns, %{route_type: [1, 2]})
      non_matching_assigns = Map.merge(assigns, %{route_type: [2, 3]})

      assert show_systemwide_alert?(matching_assigns)
      refute show_systemwide_alert?(non_matching_assigns)
    end

    test "tests whether any informed entities on the alert_banenr match a single route type", %{
      assigns: assigns
    } do
      matching_assigns = Map.merge(assigns, %{route_type: 1})
      non_matching_assigns = Map.merge(assigns, %{route_type: 2})

      assert show_systemwide_alert?(matching_assigns)
      refute show_systemwide_alert?(non_matching_assigns)
    end

    test "returns false if any required assigns properties are missing", %{assigns: assigns} do
      refute show_systemwide_alert?(assigns)
    end
  end

  describe "group_header_path/1" do
    test "for routes" do
      route = %Route{id: "Red"}
      assert group_header_path(route) == "/schedules/Red"
    end

    test "for stops" do
      stop = %Stop{id: "place-sstat"}
      assert group_header_path(stop) == "/stops/place-sstat"
    end
  end
end
