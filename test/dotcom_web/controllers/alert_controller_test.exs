defmodule DotcomWeb.AlertControllerTest do
  use DotcomWeb.ConnCase, async: true

  use Phoenix.Controller

  import Phoenix.LiveViewTest

  alias Alerts.Alert
  alias DotcomWeb.PartialView.SvgIconWithCircle
  alias Stops.Stop

  import DotcomWeb.AlertController, only: [excluding_banner: 2, group_access_alerts: 1]
  import Mox
  import Test.Support.Factories.Routes.Route

  setup :verify_on_exit!

  setup do
    cache = Application.get_env(:dotcom, :cache)
    cache.flush()

    stub(Alerts.Repo.Mock, :by_route_ids, fn _ids, _date ->
      []
    end)

    stub(Routes.Repo.Mock, :by_type, fn route_type ->
      build_list(2, :route, %{type: route_type})
    end)

    :ok
  end

  test "renders commuter rail", %{conn: conn} do
    expect(Routes.Repo.Mock, :by_type, fn 2 ->
      build_list(2, :route, %{type: 2})
    end)

    conn = get(conn, alert_path(conn, :show, "commuter-rail"))
    assert html_response(conn, 200) =~ "Commuter Rail"
  end

  describe "index/2" do
    test "index page is redirected to subway", %{conn: conn} do
      conn = get(conn, "/alerts")
      assert redirected_to(conn, 302) == "/alerts/subway"
    end
  end

  describe "show/2" do
    test "alerts are assigned for all modes", %{conn: conn} do
      for mode <- [:bus, "commuter-rail", :subway, :ferry] do
        conn = get(conn, alert_path(conn, :show, mode))
        assert conn.assigns.alerts
      end
    end

    test "alerts are assigned for the access tab", %{conn: conn} do
      conn = get(conn, alert_path(conn, :show, :access))
      assert conn.assigns.alerts
    end

    test "invalid mode does not assign alerts", %{conn: conn} do
      conn = get(conn, alert_path(conn, :show, :bicycle))
      refute conn.assigns[:alerts]
    end

    test "sets a custom meta description", %{conn: conn} do
      expect(Routes.Repo.Mock, :by_type, fn 3 ->
        build_list(2, :route, %{type: 3})
      end)

      conn = get(conn, alert_path(conn, :show, :bus))
      assert conn.assigns.meta_description
    end

    test "parses timeframe param", %{conn: conn} do
      all_alerts = get(conn, alert_path(conn, :show, :bus))
      assert all_alerts.assigns.alerts_timeframe == nil

      current = get(conn, alert_path(conn, :show, :bus, alerts_timeframe: "current"))
      assert current.assigns.alerts_timeframe == :current

      upcoming = get(conn, alert_path(conn, :show, :bus, alerts_timeframe: "upcoming"))
      assert upcoming.assigns.alerts_timeframe == :upcoming

      bad_param = get(conn, alert_path(conn, :show, :bus, alerts_timeframe: "foobar"))
      assert bad_param.assigns.alerts_timeframe == nil
    end
  end

  describe "mode icons" do
    setup %{conn: conn} do
      {:ok,
       conn: conn,
       alerts: Enum.map([:bus, :subway, :commuter_rail, :ferry, :access], &create_alert/1)}
    end

    test "are shown on subway alerts", %{conn: conn, alerts: alerts} do
      route_id = get_route(:subway) |> Map.get(:id)
      response = render_alerts_page(conn, :subway, alerts)

      expected =
        render_component(
          &DotcomWeb.Components.RoutePills.route_pill/1,
          %{route_id: route_id}
        )

      assert response =~ expected
    end

    test "are not shown on non-subway alerts", %{conn: conn, alerts: alerts} do
      for mode <- [:bus, :commuter_rail, :access] do
        response = render_alerts_page(conn, mode, alerts)
        assert response =~ "m-alerts-header"
        refute response =~ mode_icon_tag(mode)
      end
    end

    defp render_alerts_page(conn, mode, alerts) do
      conn
      |> assign(:alerts_timeframe, nil)
      |> assign(:date_time, ~N[2000-01-01 23:00:07])
      |> put_view(DotcomWeb.AlertView)
      |> render(
        "show.html",
        id: mode,
        alert_groups: alerts,
        breadcrumbs: ["Alerts"],
        date: Util.now()
      )
      |> html_response(200)
    end

    defp mode_icon_tag(mode) do
      %SvgIconWithCircle{icon: mode}
      |> SvgIconWithCircle.svg_icon_with_circle()
      |> Phoenix.HTML.safe_to_string()
      |> Kernel.<>(mode |> get_route |> Map.get(:name))
    end

    defp create_alert(mode) do
      mode
      |> get_route
      |> do_create_alert(mode)
    end

    defp get_route(:ferry),
      do: %Routes.Route{id: "Boat-F4", description: :ferry, name: "Charlestown Ferry", type: 4}

    defp get_route(:bus),
      do: %Routes.Route{id: "59", description: :local_bus, name: "59", type: 3}

    defp get_route(mode) when mode in [:subway, :access, :red_line],
      do: %Routes.Route{id: "Red", description: :rapid_transit, name: "Red Line", type: 1}

    defp get_route(:commuter_rail),
      do: %Routes.Route{
        id: "CR-Fitchburg",
        description: :commuter_rail,
        name: "Fitchburg Line",
        type: 2
      }

    defp do_create_alert(route, mode) do
      {route,
       [
         Alert.new(
           active_period: [{Util.now() |> Timex.shift(days: -2), nil}],
           informed_entity: [informed_entity(mode)],
           updated_at: Util.now() |> Timex.shift(days: -2),
           effect: effect(mode)
         )
       ]}
    end

    defp informed_entity(mode) when mode in [:subway, :access] do
      %Alerts.InformedEntity{route: "Red", route_type: 1, direction_id: 1}
    end

    defp informed_entity(:commuter_rail) do
      %Alerts.InformedEntity{route: "CR-Fitchburg", route_type: 2, direction_id: 1}
    end

    defp informed_entity(:bus) do
      %Alerts.InformedEntity{
        route: "59",
        route_type: 3,
        direction_id: nil,
        stop: "81448",
        trip: nil
      }
    end

    defp informed_entity(:ferry) do
      %Alerts.InformedEntity{
        route: "Boat-F4",
        route_type: 4,
        direction_id: 1,
        stop: "Boat-Charlestown"
      }
    end

    defp effect(:commuter_rail), do: :track_change
    defp effect(:access), do: :access_issue
    defp effect(_mode), do: :delay
  end

  describe "group_access_alerts/1" do
    test "given a list of alerts, groups the access alerts by stop" do
      stop_id1 = Faker.Internet.slug()
      stop_id2 = Faker.Internet.slug()

      stub(Stops.Repo.Mock, :get_parent, fn id ->
        %Stop{id: id}
      end)

      alerts = [
        Alert.new(
          id: "stop-1-escalator-alert",
          effect: :escalator_closure,
          header: "Escalator Alert 1",
          informed_entity: [%Alerts.InformedEntity{stop: stop_id1}]
        ),
        Alert.new(
          id: "stop-2-alert",
          effect: :escalator_closure,
          header: "Escalator Alert 2",
          informed_entity: [%Alerts.InformedEntity{stop: stop_id2}]
        ),
        Alert.new(
          id: "stop-1-access-alert",
          effect: :access_issue,
          header: "Access Alert",
          informed_entity: [%Alerts.InformedEntity{stop: stop_id1}]
        )
      ]

      grouped = alerts |> group_access_alerts() |> Map.new()
      stop1 = %Stop{id: stop_id1}
      stop2 = %Stop{id: stop_id2}

      assert [access, escalator] = grouped |> Map.get(stop1) |> MapSet.to_list()
      assert escalator.id == "stop-1-escalator-alert"
      assert access.id == "stop-1-access-alert"
      assert [south_station_alert] = grouped |> Map.get(stop2) |> MapSet.to_list()
      assert south_station_alert.id == "stop-2-alert"
    end

    test "deduplicates child stops" do
      child_stop = %Stop{id: "child-stop", parent_id: "parent-stop"}
      parent_stop = %Stop{id: "parent-stop", child_ids: ["child-stop"]}

      stub(Stops.Repo.Mock, :get_parent, fn _ ->
        parent_stop
      end)

      alerts = [
        Alert.new(
          id: "escalator-alert",
          effect: :escalator_closure,
          header: "Escalator Alert 1",
          informed_entity: [%Alerts.InformedEntity{stop: parent_stop.id}]
        ),
        Alert.new(
          id: "access-alert",
          effect: :access_issue,
          header: "Access Alert",
          informed_entity: [%Alerts.InformedEntity{stop: child_stop.id}]
        )
      ]

      grouped = group_access_alerts(alerts)
      assert Enum.map(grouped, fn {stop, _} -> stop.id end) == [parent_stop.id]

      assert [%Alert{}, %Alert{}] =
               grouped |> Map.new() |> Map.get(parent_stop) |> MapSet.to_list()
    end

    test "ignores bad stop ids" do
      stub(Stops.Repo.Mock, :get_parent, fn _ ->
        nil
      end)

      alert = [
        Alert.new(
          id: "bad-stop-id",
          effect: :escalator_closure,
          header: "Escalator alert",
          informed_entity: [%Alerts.InformedEntity{stop: "does-not-exist"}]
        )
      ]

      assert group_access_alerts(alert) == []
    end
  end

  describe "mTicket detection" do
    test "mTicket matched", %{conn: conn} do
      expect(Routes.Repo.Mock, :by_type, fn 2 ->
        build_list(4, :route, %{type: 2})
      end)

      response =
        conn
        |> put_req_header("user-agent", "Java/1.8.0_91")
        |> get(alert_path(conn, :show, "commuter-rail"))
        |> html_response(200)

      assert response =~ "mticket-notice"
      assert response =~ "access alerts:"
      assert response =~ "/alerts/commuter-rail"
    end

    test "mTicket not matched", %{conn: conn} do
      expect(Routes.Repo.Mock, :by_type, fn 2 ->
        build_list(4, :route, %{type: 2})
      end)

      response =
        conn
        |> get(alert_path(conn, :show, "commuter-rail"))
        |> html_response(200)

      refute response =~ "mticket-notice"
    end
  end

  describe "excluding_banner/2" do
    setup do
      alerts = [
        %{id: "1"},
        %{id: "2"},
        %{id: "3"}
      ]

      %{alerts: alerts}
    end

    test "filters out the banner alert from a list of alerts", %{alerts: alerts} do
      expected_result = [
        %{id: "1"},
        %{id: "3"}
      ]

      assert excluding_banner(%{assigns: %{alert_banner: %{id: "2"}}}, alerts) == expected_result
    end

    test "returns the list of alerts if no banner alert is in assigns", %{alerts: alerts} do
      assert excluding_banner(%{}, alerts) == alerts
    end
  end
end
