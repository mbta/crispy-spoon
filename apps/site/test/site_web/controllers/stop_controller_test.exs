defmodule SiteWeb.StopControllerTest do
  use SiteWeb.ConnCase
  alias Routes.Route
  alias SiteWeb.StopController
  alias Stops.Stop
  alias Util.Breadcrumb

  test "renders react content server-side", %{conn: conn} do
    assert [{"div", _, content}] =
             conn
             |> put_req_cookie("stop_page_redesign", "true")
             |> get(stop_path(conn, :show, "place-sstat"))
             |> html_response(200)
             |> Floki.find("#react-root")

    assert [_ | _] = content
  end

  test "redirects to subway stops on index", %{conn: conn} do
    conn = conn |> put_req_cookie("stop_page_redesign", "true") |> get(stop_path(conn, :index))
    assert redirected_to(conn) == stop_path(conn, :show, :subway)
  end

  test "shows stations by mode", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("stop_page_redesign", "true")
      |> get(stop_path(conn, :show, :subway))

    response = html_response(conn, 200)

    for line <- ["Green", "Red", "Blue", "Orange", "Mattapan"] do
      assert response =~ line
    end
  end

  test "assigns stop_info for each mode", %{conn: conn} do
    for mode <- [:subway, :ferry, "commuter-rail"] do
      conn =
        conn
        |> put_req_cookie("stop_page_redesign", "true")
        |> get(stop_path(conn, :show, mode))

      assert conn.assigns.stop_info
    end
  end

  test "redirects stations with slashes to the right URL", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("stop_page_redesign", "true")
      |> get("/stops/Four%20Corners%20/%20Geneva")

    assert redirected_to(conn) == stop_path(conn, :show, "Four Corners / Geneva")
  end

  test "assigns routes for this stop", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("stop_page_redesign", "true")
      |> get(stop_path(conn, :show, "place-sstat"))

    assert conn.assigns.routes
  end

  test "assigns ferry routes", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("stop_page_redesign", "true")
      |> get(stop_path(conn, :show, "Boat-Charlestown"))

    assert [ferry] = conn.assigns.routes
    assert %{group_name: :ferry, routes: [%{route: %Route{id: "Boat-F4"}}]}
  end

  test "assigns the zone number for the current stop", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("stop_page_redesign", "true")
      |> get(stop_path(conn, :show, "place-WML-0442"))

    assert conn.assigns.zone_number == "8"
  end

  test "sets a custom meta description for stops", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("stop_page_redesign", "true")
      |> get(stop_path(conn, :show, "place-sstat"))

    assert conn.assigns.meta_description
  end

  test "redirects to a parent stop page for a child stop", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("stop_page_redesign", "true")
      |> get(stop_path(conn, :show, 70_130))

    assert redirected_to(conn) == stop_path(conn, :show, "place-harvd")
  end

  test "404s for an unknown stop", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("stop_page_redesign", "true")
      |> get(stop_path(conn, :show, "unknown"))

    assert Map.fetch!(conn, :status) == 404
  end

  describe "breadcrumbs/2" do
    test "returns station breadcrumbs if the stop is served by more than buses" do
      stop = %Stop{name: "Name", station?: true}
      routes = [%Route{id: "CR-Lowell", type: 2}]

      assert StopController.breadcrumbs(stop, routes) == [
               %Breadcrumb{text: "Stations", url: "/stops/commuter-rail"},
               %Breadcrumb{text: "Name", url: ""}
             ]
    end

    test "returns simple breadcrumb if the stop is served by only buses" do
      stop = %Stop{name: "Dudley Station"}
      routes = [%Route{id: "28", type: 3}]

      assert StopController.breadcrumbs(stop, routes) == [
               %Breadcrumb{text: "Dudley Station", url: ""}
             ]
    end

    test "returns simple breadcrumb if we have no route info for the stop" do
      stop = %Stop{name: "Name", station?: true}
      assert StopController.breadcrumbs(stop, []) == [%Breadcrumb{text: "Name", url: ""}]
    end
  end

  describe "json_safe_alerts/2" do
    test "returns a list of json safe alerts" do
      alerts = [
        %Alerts.Alert{
          active_period: [
            {Timex.to_datetime({{2019, 06, 20}, {20, 45, 00}}, "Etc/GMT+4"),
             Timex.to_datetime({{2019, 06, 21}, {02, 30, 00}}, "Etc/GMT+4")}
          ],
          description:
            "When the Red Sox play evening games at Fenway, trains will run until 10:30 PM to accommodate increased ridership.\r\n\r\nRegular D Branch Service will operate on: \r\nPatriots Day - April 15\r\nMemorial Day - May 27\r\n\r\nThis project is part of the MBTA initiative to bring the Green Line track and signal systems into a state of good repair. Learn more: MBTA.com/GreenLineD\r\n\r\nAffected stops:\r\nNewton Highlands\r\nEliot\r\nWaban\r\nWoodland\r\nRiverside",
          effect: :shuttle,
          header:
            "Shuttle buses replace Green Line D train service between Riverside and Newton Highlands at about 8:45 PM to end of service on weeknights through July 3. Regular service will operate on Patriot's Day, April 15. More: mbta.com/GLwork",
          id: "303815",
          informed_entity: %Alerts.InformedEntitySet{
            activities: [:board, :exit, :ride],
            direction_id: [nil],
            entities: [
              %Alerts.InformedEntity{
                activities: [:board, :ride],
                direction_id: nil,
                route: "Green-D",
                route_type: 0,
                stop: "70160",
                trip: nil
              },
              %Alerts.InformedEntity{
                activities: [:board, :ride],
                direction_id: nil,
                route: "Green",
                route_type: 0,
                stop: "70160",
                trip: nil
              }
            ],
            route: ["Green", "Green-D"],
            route_type: [0],
            stop: [
              "70160",
              "70161",
              "70162",
              "70163",
              "70164",
              "70165",
              "70166",
              "70167",
              "70168",
              "70169",
              "place-eliot",
              "place-newtn",
              "place-river",
              "place-waban",
              "place-woodl"
            ],
            trip: [nil]
          },
          lifecycle: :upcoming,
          priority: :low,
          severity: 5,
          updated_at: Timex.to_datetime({{2019, 04, 15}, {05, 54, 24}}, "Etc/GMT+4")
        }
      ]

      assert [
               %{
                 active_period: [["2019-6-20 8:45", "2019-6-21 2:30"]],
                 description:
                   "When the Red Sox play evening games at Fenway, trains will run until 10:30 PM to accommodate increased ridership.<br />\r<br /><strong>Regular D Branch Service will operate on:</strong><br />Patriots Day - April 15<br />Memorial Day - May 27<br />\r<br /><strong>This project is part of the MBTA initiative to bring the Green Line track and signal systems into a state of good repair. Learn more:</strong><br /><a target=\"_blank\" href=\"http://MBTA.com/GreenLineD\">MBTA.com/GreenLineD</a><br />\r<br /><strong>Affected stops:</strong><br />Newton Highlands<br />Eliot<br />Waban<br />Woodland<br />Riverside",
                 effect: :shuttle,
                 header:
                   "Shuttle buses replace Green Line D train service between Riverside and Newton Highlands at about 8:45 PM to end of service on weeknights through July 3. Regular service will operate on Patriot's Day, April 15. More: <a target=\"_blank\" href=\"http://mbta.com/GLwork\">mbta.com/GLwork</a>",
                 id: "303815",
                 informed_entity: %Alerts.InformedEntitySet{
                   activities: [:board, :exit, :ride],
                   direction_id: [nil],
                   entities: [
                     %Alerts.InformedEntity{
                       activities: [:board, :ride],
                       direction_id: nil,
                       route: "Green-D",
                       route_type: 0,
                       stop: "70160",
                       trip: nil
                     },
                     %Alerts.InformedEntity{
                       activities: [:board, :ride],
                       direction_id: nil,
                       route: "Green",
                       route_type: 0,
                       stop: "70160",
                       trip: nil
                     }
                   ],
                   route: ["Green", "Green-D"],
                   route_type: [0],
                   stop: [
                     "70160",
                     "70161",
                     "70162",
                     "70163",
                     "70164",
                     "70165",
                     "70166",
                     "70167",
                     "70168",
                     "70169",
                     "place-eliot",
                     "place-newtn",
                     "place-river",
                     "place-waban",
                     "place-woodl"
                   ],
                   trip: [nil]
                 },
                 lifecycle: :upcoming,
                 priority: :low,
                 severity: 5,
                 updated_at: "Updated: 4/15/2019 05:54A"
               }
             ] =
               StopController.json_safe_alerts(
                 alerts,
                 Timex.to_datetime({{2019, 04, 15}, {15, 33, 30}}, "Etc/GMT+4")
               )
    end
  end

  describe "api" do
    test "returns json with departure data", %{conn: conn} do
      path = stop_path(conn, :api, id: "place-sstat")
      assert path == "/stops/api?id=place-sstat"

      response =
        conn
        |> get(path)
        |> json_response(200)

      assert is_list(response)
      refute Enum.empty?(response)

      for item <- response do
        assert %{"group_name" => _, "routes" => _} = item
      end
    end
  end
end
