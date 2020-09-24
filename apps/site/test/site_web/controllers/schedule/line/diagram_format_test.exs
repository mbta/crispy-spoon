defmodule SiteWeb.ScheduleController.Line.DiagramFormatTest do
  use ExUnit.Case, async: true

  import SiteWeb.DiagramHelpers
  import SiteWeb.ScheduleController.Line.DiagramFormat
  alias Alerts.Alert
  alias Alerts.InformedEntity, as: IE

  @now Timex.now()

  setup_all do
    {:ok,
     simple_line_diagram: setup_simple_line_diagram(),
     outward_line_diagram: setup_outward_line_diagram(),
     inward_line_diagram: setup_inward_line_diagram()}
  end

  @doc "Creates a new alert and adds it to stops list"
  def stops_with_effect(effect, stop_ids, base_list \\ @stops_list_base, alert_id \\ 1) do
    stop_list =
      base_list
      |> Enum.map(fn %{route_stop: %RouteStop{id: id}, alerts: alerts} = stop ->
        if id in stop_ids do
          %{
            stop
            | alerts: [
                Alert.new(
                  id: alert_id,
                  lifecycle: :ongoing,
                  effect: effect,
                  informed_entity: Enum.map(stop_ids, &%IE{stop: &1}),
                  active_period: [{Timex.shift(@now, days: -1), Timex.shift(@now, days: 1)}]
                )
                | alerts
              ]
          }
        else
          stop
        end
      end)

    stop_list
  end

  def disruption(stop_data) do
    %{has_disruption?: has_disruption} = List.last(stop_data)
    has_disruption
  end

  def disrupted_stop_ids(stops_list) do
    stops_list
    |> Enum.filter(&disruption(&1.stop_data))
    |> Enum.map(& &1.route_stop.id)
  end

  describe "do_stops_list_with_disruptions/2" do
    test "formats shuttle stops" do
      stops = stops_with_effect(:shuttle, ["place-nqncy", "place-brntn"])
      adjusted_stops = do_stops_list_with_disruptions(stops, @now)
      assert ["place-nqncy"] = adjusted_stops |> disrupted_stop_ids()
    end

    test "formats detour stops" do
      stops = stops_with_effect(:detour, ["place-nqncy", "place-brntn"])
      adjusted_stops = do_stops_list_with_disruptions(stops, @now)
      assert ["place-jfk", "place-nqncy", "place-brntn"] = adjusted_stops |> disrupted_stop_ids()
    end

    test "formats stop closure stops" do
      stops = stops_with_effect(:stop_closure, ["place-nqncy", "place-brntn"])
      adjusted_stops = do_stops_list_with_disruptions(stops, @now)
      assert ["place-jfk", "place-nqncy", "place-brntn"] = adjusted_stops |> disrupted_stop_ids()
    end

    test "formats stops list with first shuttle" do
      stops = stops_with_effect(:shuttle, ["place-alfcl", "place-jfk"])

      adjusted_stops = do_stops_list_with_disruptions(stops, @now)
      assert ["place-alfcl"] = adjusted_stops |> disrupted_stop_ids()
    end

    test "formats stops list with second shuttle" do
      stops = stops_with_effect(:shuttle, ["place-shmnl", "place-asmnl"])

      adjusted_stops = do_stops_list_with_disruptions(stops, @now)
      assert ["place-shmnl"] = adjusted_stops |> disrupted_stop_ids()
    end

    test "formats stops list with first and second shuttle" do
      stops_with_first_shuttle = stops_with_effect(:shuttle, ["place-alfcl", "place-jfk"])

      stops =
        stops_with_effect(:shuttle, ["place-shmnl", "place-asmnl"], stops_with_first_shuttle, 2)

      adjusted_stops = do_stops_list_with_disruptions(stops, @now)
      assert ["place-alfcl", "place-shmnl"] = adjusted_stops |> disrupted_stop_ids()
    end

    test "formats stops for some other alert effect" do
      stops = stops_with_effect(:unknown, ["place-nqncy", "place-brntn"])
      adjusted_stops = do_stops_list_with_disruptions(stops, @now)
      assert [] = adjusted_stops |> disrupted_stop_ids()
    end

    test "handles no alerts" do
      adjusted_stops = do_stops_list_with_disruptions(@stops_list_base, @now)
      refute Enum.any?(adjusted_stops, &disruption(&1.stop_data))
    end
  end

  defp setup_simple_line_diagram do
    [
      {"place-alfcl", [stop: nil]},
      {"place-jfk", [stop: nil]},
      {"place-nqncy", [stop: nil]},
      {"place-brntn", [stop: nil]},
      {"place-shmnl", [stop: nil]},
      {"place-asmnl", [stop: nil]}
    ]
    |> route_stops_to_line_diagram_stops()
  end

  defp setup_inward_line_diagram do
    [
      {"place-asmnl", [terminus: "Alewife - Ashmont"]},
      {"place-shmnl", [stop: "Alewife - Ashmont"]},
      {"place-brntn", [line: "Alewife - Ashmont", terminus: "Alewife - Braintree"]},
      {"place-nqncy", [line: "Alewife - Ashmont", stop: "Alewife - Braintree"]},
      {"place-jfk", [merge: "Alewife - Ashmont", merge: "Alewife - Braintree"]},
      {"place-alfcl", [terminus: nil]}
    ]
    |> route_stops_to_line_diagram_stops()
  end

  defp setup_outward_line_diagram do
    [
      {"place-alfcl", [terminus: nil]},
      {"place-jfk", [merge: "Alewife - Ashmont", merge: "Alewife - Braintree"]},
      {"place-nqncy", [line: "Alewife - Ashmont", stop: "Alewife - Braintree"]},
      {"place-brntn", [line: "Alewife - Ashmont", terminus: "Alewife - Braintree"]},
      {"place-shmnl", [stop: "Alewife - Ashmont"]},
      {"place-asmnl", [terminus: "Alewife - Ashmont"]}
    ]
    |> route_stops_to_line_diagram_stops()
  end
end
