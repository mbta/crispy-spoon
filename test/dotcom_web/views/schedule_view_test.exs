defmodule DotcomWeb.ScheduleViewTest do
  use DotcomWeb.ConnCase

  import DotcomWeb.ScheduleView
  import Mox
  import PhoenixHTMLHelpers.Tag, only: [content_tag: 3]
  import Phoenix.HTML, only: [safe_to_string: 1]

  alias CMS.Partial.RoutePdf
  alias Routes.Route
  alias Stops.Stop

  setup :verify_on_exit!

  describe "template_for_tab/1" do
    test "returns the template corresponding to a tab value" do
      assert template_for_tab("timetable") == "_timetable.html"
      assert template_for_tab("line") == "_line.html"
    end
  end

  describe "route_fare_link/1" do
    test "returns proper link to different fares pages" do
      assert route_fare_link(%Routes.Route{type: 0}) == "/fares/subway-fares"
      assert route_fare_link(%Routes.Route{type: 1}) == "/fares/subway-fares"
      assert route_fare_link(%Routes.Route{type: 2}) == "/fares/commuter-rail-fares"
      assert route_fare_link(%Routes.Route{type: 3}) == "/fares/bus-fares"
      assert route_fare_link(%Routes.Route{type: 4}) == "/fares/ferry-fares"
    end
  end

  describe "reverse_direction_opts/1" do
    test "reverses direction" do
      expected = [
        trip: nil,
        schedule_direction: %{
          direction_id: "1"
        }
      ]

      actual = reverse_direction_opts("1")

      assert Enum.sort(expected) == Enum.sort(actual)
    end
  end

  describe "no_trips_message/3" do
    test "when a no service error is provided" do
      error = %JsonApi.Error{
        code: "no_service",
        meta: %{"version" => "Spring 2017 version 3D", "end_date" => "2018-05-31"}
      }

      result =
        error
        |> no_trips_message(nil, ~D[2017-01-01])
        |> Enum.map(&safe_to_string/1)
        |> IO.iodata_to_binary()

      assert result =~
               "We can only provide trip data for the Spring schedule, valid until May 31, 2018"
    end

    test "when a starting and ending stop are provided" do
      result =
        no_trips_message(
          nil,
          nil,
          ~D[2017-03-05]
        )

      assert IO.iodata_to_binary(result) ==
               "There are no scheduled trips on March 5, 2017."
    end

    test "when a direction is provided" do
      result = no_trips_message(nil, "Inbound", ~D[2017-03-05])

      assert IO.iodata_to_binary(result) ==
               "There are no scheduled inbound trips on March 5, 2017."
    end

    test "fallback when nothing is available" do
      result = no_trips_message(nil, nil, nil)
      assert IO.iodata_to_binary(result) == "There are no scheduled trips."
    end

    test "does not downcase non-traditional directions" do
      error = nil
      # CR-Foxboro
      direction = "TF Green Airport"
      date = ~D[2017-11-01]
      result = no_trips_message(error, direction, date)

      assert IO.iodata_to_binary(result) ==
               "There are no scheduled TF Green Airport trips on November 1, 2017."
    end
  end

  describe "route_pdfs/3" do
    test "returns empty array if no pdfs" do
      assert [] = route_pdfs([], %Routes.Route{}, ~D[2019-04-29])
    end

    test "returns map of pdfs" do
      pdfs = [
        %RoutePdf{path: "/basic-current-url", date_start: ~D[2017-12-01]},
        %RoutePdf{path: "/basic-future-url", date_start: ~D[2119-02-01]},
        %RoutePdf{
          path: "/custom-url",
          date_start: ~D[2017-12-01],
          link_text_override: "Custom schedule"
        }
      ]

      maps = route_pdfs(pdfs, %Routes.Route{name: "1", type: 3}, ~D[2019-01-29])
      assert List.first(maps).url =~ ~r"http://.*/basic-current-url"
      assert List.first(maps).title =~ "Current Route 1 schedule and map PDF"
      assert List.last(maps).url =~ ~r"http://.*/custom-url"
      assert List.last(maps).title =~ "Current Custom schedule PDF"
    end
  end

  describe "route_pdf_link/3" do
    test "returns an empty list if no PDF for that route" do
      route = %Routes.Route{}
      today = ~D[2018-01-01]

      assert [{"div", _, []}] =
               []
               |> route_pdf_link(route, today)
               |> safe_to_string
               |> Floki.parse_fragment()
               |> elem(1)

      assert [{"div", _, []}] =
               nil
               |> route_pdf_link(route, today)
               |> safe_to_string
               |> Floki.parse_fragment()
               |> elem(1)
    end

    test "shows all PDFs for the route" do
      route_pdfs = [
        %RoutePdf{path: "/basic-current-url", date_start: ~D[2017-12-01]},
        %RoutePdf{path: "/basic-future-url", date_start: ~D[2119-02-01]},
        %RoutePdf{
          path: "/custom-url",
          date_start: ~D[2017-12-01],
          link_text_override: "Custom schedule"
        }
      ]

      route = %Routes.Route{name: "1", type: 3}
      rendered = safe_to_string(route_pdf_link(route_pdfs, route, ~D[2018-01-01]))
      assert rendered =~ "Current Route 1 schedule and map PDF"
      assert rendered =~ "basic-current-url"
      # full URL
      assert rendered =~ "http://"
      assert rendered =~ "Current Custom schedule PDF"
      assert rendered =~ "Upcoming Route 1 schedule and map PDF — effective Feb 1"
    end

    test "does not specify 'current' when all schedules are current" do
      route_pdfs = [
        %RoutePdf{path: "/basic-current-url", date_start: ~D[2017-12-01]},
        %RoutePdf{
          path: "/custom-url",
          date_start: ~D[2017-12-01],
          link_text_override: "Custom schedule"
        }
      ]

      route = %Routes.Route{name: "1", type: 3}
      rendered = safe_to_string(route_pdf_link(route_pdfs, route, ~D[2018-01-01]))
      assert rendered =~ "Route 1 schedule and map PDF"
      assert rendered =~ "Custom schedule PDF"
    end

    test "considers PDFs that start today as current" do
      route_pdfs = [%RoutePdf{path: "/url", date_start: ~D[2018-01-01]}]
      route = %Routes.Route{name: "1", type: 3}
      rendered = safe_to_string(route_pdf_link(route_pdfs, route, ~D[2018-01-01]))
      assert rendered =~ "Route 1 schedule and map PDF"
    end
  end

  describe "pretty_route_name/1" do
    test "has correct text for bus routes" do
      route = %Routes.Route{id: "741", name: "SL1", type: 3}
      assert pretty_route_name(route) == "Route SL1"
    end

    test "has correct name for subway" do
      route = %Routes.Route{id: "Red", name: "Red Line", type: 1}
      assert pretty_route_name(route) == "Red line"
    end

    test "has correct name for ferries" do
      route = %Routes.Route{id: "Boat-F4", name: "Charlestown Ferry", type: 1}
      assert pretty_route_name(route) == "Charlestown ferry"
    end

    test "has correct name for mattapan" do
      route = %Routes.Route{id: "Mattapan", name: "Mattapan Trolley", type: 1}
      assert pretty_route_name(route) == "Mattapan trolley"
    end

    test "allows line break after slash" do
      route = %Routes.Route{id: "CR-Worcester", name: "Framingham/Worcester Line", type: 1}
      # expected result has a zero-width space bewtween / and W
      assert pretty_route_name(route) == "Framingham/​Worcester line"
    end
  end

  describe "_empty.html" do
    @date ~D[2016-01-01]

    test "shows date reset link when not current date", %{conn: conn} do
      conn = %{conn | query_params: %{}}

      rendered =
        DotcomWeb.ScheduleView.render(
          "_empty.html",
          error: nil,
          origin: "origin",
          destination: "dest",
          direction: "inbound",
          date: @date,
          conn: conn
        )

      assert safe_to_string(rendered) =~ "View inbound trips"
    end

    test "Does not show reset link if selected date is service date", %{conn: conn} do
      conn = %{conn | query_params: %{}}

      rendered =
        DotcomWeb.ScheduleView.render(
          "_empty.html",
          error: nil,
          origin: "origin",
          destination: "dest",
          direction: "inbound",
          date: Util.service_date(),
          conn: conn
        )

      refute safe_to_string(rendered) =~ "View inbound trips"
    end

    test "Does not list date if none is given", %{conn: conn} do
      conn = %{conn | query_params: %{}}

      rendered =
        DotcomWeb.ScheduleView.render(
          "_empty.html",
          error: nil,
          origin: nil,
          destination: nil,
          direction: "inbound",
          date: nil,
          conn: conn
        )

      refute safe_to_string(rendered) =~ "on"
      assert safe_to_string(rendered) =~ "There are no scheduled inbound"
    end
  end

  describe "fare_params/2" do
    @origin %Stop{id: "place-north"}
    @destination %Stop{id: "Fitchburg"}

    test "fare link when no origin/destination chosen" do
      assert fare_params(nil, nil) == %{}
    end

    test "fare link when only origin chosen" do
      assert fare_params(@origin, nil) == %{origin: @origin}
    end

    test "fare link when origin and destination chosen" do
      assert fare_params(@origin, @destination) == %{origin: @origin, destination: @destination}
    end
  end

  describe "route_header_text/2" do
    test "translates the type number to a string or number if non-silver-line bus" do
      assert route_header_text(%Route{type: 0, name: "test route"}) == ["test route"]
      assert route_header_text(%Route{type: 3, name: "SL1", id: "741"}) == ["Silver Line ", "SL1"]

      assert route_header_text(%Route{type: 3, name: "SLW", id: "746"}) ==
               "Silver Line Waterfront"

      assert route_header_text(%Route{type: 3, name: "2"}) ==
               content_tag(:div, "2", class: "bus-route-sign")

      assert route_header_text(%Route{type: 1, name: "Red Line"}) == ["Red Line"]
      assert route_header_text(%Route{type: 2, name: "Fitchburg Line"}) == ["Fitchburg"]
    end
  end

  describe "route_header_description/1" do
    test "Uses long name for bus or Bus Route if it's missing" do
      assert route_header_description(%Route{type: 3, name: "short", long_name: "long"}) ==
               content_tag(:h2, "long", class: "schedule__description notranslate")

      assert route_header_description(%Route{type: 3, name: "short", long_name: ""}) ==
               content_tag(:h2, "Bus Route", class: "schedule__description notranslate")
    end
  end

  describe "route_header_class/1" do
    test "returns a line-specific background class for silver line and subway" do
      expect(Routes.Repo.Mock, :green_line, fn ->
        Routes.Repo.green_line()
      end)

      assert header_class(%Route{type: 3, id: "741"}) == "u-bg--silver-line"
      assert header_class(%Route{type: 0, id: "Green-B"}) == "u-bg--green-line"
      assert header_class(%Route{type: 1, id: "Red"}) == "u-bg--red-line"
    end

    test "returns a mode-specific background class for other modes" do
      assert header_class(%Route{type: 2, id: "CR-Fitchburg"}) == "u-bg--commuter-rail"
      assert header_class(%Route{type: 3, id: "2"}) == "u-bg--bus"
      assert header_class(%Route{type: 3, id: "2"}) == "u-bg--bus"
      assert header_class(%Route{type: 4, id: "Boat-Hull"}) == "u-bg--ferry"
    end
  end

  describe "route_header_tabs/1" do
    test "returns 4 tabs for commuter rail (1 hidden by css)", %{conn: conn} do
      tabs =
        conn
        |> assign(:route, %Route{type: 2})
        |> assign(:tab, "alerts")
        |> assign(:tab_params, [])
        |> route_header_tabs()
        |> safe_to_string()

      assert tabs =~ "schedule-&amp;-maps-tab"
      assert tabs =~ "timetable-tab"
      assert tabs =~ "alerts-tab"
    end

    test "returns 3 tabs for other routes (1 hidden by CSS)", %{conn: conn} do
      tabs =
        conn
        |> assign(:route, %Route{type: 3})
        |> assign(:tab, "alerts")
        |> assign(:tab_params, [])
        |> route_header_tabs()
        |> safe_to_string()

      assert tabs =~ "schedules-&amp;-maps-tab"
      assert tabs =~ "alerts-tab"
      refute tabs =~ "info-tab"
      refute tabs =~ "timetable-tab"
    end
  end

  describe "to_fare_summary_atom/1" do
    test "silver line returns subway" do
      assert to_fare_summary_atom(%Route{type: 3, id: "741"}) == :subway
    end

    test "express bus returns :express_bus" do
      assert to_fare_summary_atom(%Route{type: 3, id: "170"}) == :express_bus
    end

    test "other types of routes return specific atoms" do
      assert to_fare_summary_atom(%Route{type: 0, id: "Green-B"}) == :subway
      assert to_fare_summary_atom(%Route{type: 1, id: "Red"}) == :subway
      assert to_fare_summary_atom(%Route{type: 2, id: "CR-Fitchburg"}) == :commuter_rail
      assert to_fare_summary_atom("commuter_rail") == :commuter_rail
      assert to_fare_summary_atom(%Route{type: 3, id: "1"}) == :bus
    end
  end

  describe "sort_connnections/1" do
    test "sorts subway in the correct order, followed by commuter rail alphabetical" do
      routes = [
        %Route{id: "Green-E"},
        %Route{id: "Mattapan"},
        %Route{id: "Green-B"},
        %Route{id: "Green-D"},
        %Route{id: "Red"},
        %Route{id: "Green-C"},
        %Route{id: "Orange"},
        %Route{id: "Blue"},
        %Route{type: 2, name: "Worcester"},
        %Route{type: 2, name: "Fitchburg"}
      ]

      sorted_routes = [
        %Route{id: "Red"},
        %Route{id: "Orange"},
        %Route{id: "Green-B"},
        %Route{id: "Green-C"},
        %Route{id: "Green-D"},
        %Route{id: "Green-E"},
        %Route{id: "Blue"},
        %Route{id: "Mattapan"},
        %Route{type: 2, name: "Fitchburg"},
        %Route{type: 2, name: "Worcester"}
      ]

      assert sort_connections(routes) == sorted_routes
    end
  end

  describe "single_trip_fares/1" do
    test "free routes return free fares" do
      assert [{_, "Free"}] = single_trip_fares(%Route{fare_class: :free_fare})
    end

    test "only return summary for single_trip fares" do
      assert single_trip_fares(%Route{type: 2, name: "Fitchburg"}) == [
               {"Zones 1A-10", ["$2.40", " – ", "$13.25"]}
             ]
    end
  end

  describe "timetable_note" do
    test "returns a timetable note for foxboro" do
      refute is_nil(
               timetable_note(%{
                 route: %Route{id: "CR-Foxboro"},
                 direction_id: 1,
                 date: ~D[2019-10-21]
               })
             )
    end

    test "doesn't return a timetable note for other routes" do
      assert is_nil(
               timetable_note(%{
                 route: %Route{id: "CR-Lowell"},
                 direction_id: 0,
                 date: ~D[2019-10-20]
               })
             )
    end
  end

  describe "station?" do
    test "returns true if stop is station" do
      assert station?(%Stop{id: "place-north", station?: true}) == true
    end

    test "returns false if stop is not a station" do
      assert station?(%Stop{id: "11257", station?: false}) == false
    end
  end
end
