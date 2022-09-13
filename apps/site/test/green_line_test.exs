defmodule GreenLineTest do
  use ExUnit.Case, async: true

  import GreenLine

  describe "stops_on_routes/1" do
    test "returns ordered stops on the green line by direction ID" do
      {stops, _} = stops_on_routes(0)
      earlier_stop = Enum.find_index(stops, &(&1.id == "place-gover"))
      later_stop = Enum.find_index(stops, &(&1.id == "place-lake"))
      assert earlier_stop < later_stop
    end

    test "returns a set of {stop_id, route_id} pairs" do
      {_, route_id_stop_map} = stops_on_routes(1)

      refute "place-unsqu" in route_id_stop_map["Green-B"]
      refute "place-unsqu" in route_id_stop_map["Green-C"]
      assert "place-unsqu" in route_id_stop_map["Green-D"]
      # As of Aug 2022, the Green Line past Government Center is temporarily suspended.
      # assert "place-unsqu" in route_id_stop_map["Green-E"]

      refute "place-lech" in route_id_stop_map["Green-B"]
      refute "place-lech" in route_id_stop_map["Green-C"]
      assert "place-lech" in route_id_stop_map["Green-D"]
      # As of Aug 2022, the Green Line past Government Center is temporarily suspended.
      # assert "place-lech" in route_id_stop_map["Green-E"]

      assert "place-coecl" in route_id_stop_map["Green-B"]
      assert "place-coecl" in route_id_stop_map["Green-C"]
      assert "place-coecl" in route_id_stop_map["Green-D"]
      assert "place-coecl" in route_id_stop_map["Green-E"]

      assert "place-kencl" in route_id_stop_map["Green-B"]
      assert "place-kencl" in route_id_stop_map["Green-C"]
      assert "place-kencl" in route_id_stop_map["Green-D"]
      refute "place-kencl" in route_id_stop_map["Green-E"]
    end
  end

  describe "calculate_stops_on_routes/1" do
    def stops_fn(route, _, _) do
      case route do
        "Green-B" ->
          []

        "Green-C" ->
          [
            %Stops.Stop{id: "place-clmnl"},
            %Stops.Stop{id: "place-coecl"},
            %Stops.Stop{id: "place-kencl"},
            %Stops.Stop{id: "place-gover"}
          ]

        "Green-D" ->
          [
            %Stops.Stop{id: "place-river"},
            %Stops.Stop{id: "place-coecl"},
            %Stops.Stop{id: "place-kencl"},
            %Stops.Stop{id: "place-gover"},
            %Stops.Stop{id: "place-north"}
          ]

        "Green-E" ->
          [
            %Stops.Stop{id: "place-hsmnl"},
            %Stops.Stop{id: "place-gover"},
            %Stops.Stop{id: "place-north"}
            # %Stops.Stop{id: "place-lech"}
          ]
      end
    end

    test "each line returns a set of the ids of associated stops" do
      {_, stop_map} = calculate_stops_on_routes(0, Timex.today(), &stops_fn/3)

      assert stop_map["Green-C"] ==
               MapSet.new(["place-clmnl", "place-coecl", "place-gover", "place-kencl"])

      assert stop_map["Green-D"] ==
               MapSet.new([
                 "place-north",
                 "place-coecl",
                 "place-gover",
                 "place-kencl",
                 "place-river"
               ])

      # As of June 2020, Lechmere is closed for construction and the E-line will
      # be terminating at North Station for now.
      # assert stop_map["Green-E"] ==
      #  MapSet.new(["place-hsmnl", "place-gover", "place-north", "place-lech"])
      # As of Aug 2022, the Green Line Union Square branch is temporarily suspended.
      # assert stop_map["Green-E"] ==
      #          MapSet.new(["place-hsmnl", "place-gover", "place-north"])
      assert stop_map["Green-E"] ==
               MapSet.new(["place-gover", "place-hsmnl", "place-north"])
    end

    test "a list of stops without duplicates is returned" do
      {stops, _} = calculate_stops_on_routes(0, Timex.today(), &stops_fn/3)

      assert Enum.sort(stops) ==
               Enum.sort([
                 %Stops.Stop{id: "place-hsmnl"},
                 %Stops.Stop{id: "place-gover"},
                 %Stops.Stop{id: "place-north"},
                 %Stops.Stop{id: "place-coecl"},
                 %Stops.Stop{id: "place-kencl"},
                 # As of June 2020, Lechmere is closed for construction
                 #  %Stops.Stop{id: "place-lech"},
                 %Stops.Stop{id: "place-clmnl"},
                 %Stops.Stop{id: "place-river"}
               ])
    end

    test "if a line returns no stops, it is represented in the map by an empty set" do
      {_, stop_map} = calculate_stops_on_routes(0, Timex.today(), &stops_fn/3)

      assert stop_map["Green-B"] == MapSet.new()
    end
  end

  describe "all_stops/1" do
    test "can return an error" do
      gl = stops_on_routes(0, ~D[2017-01-01])
      assert {:error, _} = all_stops(gl)
    end
  end

  test "terminus?/2" do
    for stop_id <- ["place-lake", "place-gover"] do
      assert terminus?(stop_id, "Green-B")
    end

    for stop_id <- ["place-gover", "place-clmnl"] do
      assert terminus?(stop_id, "Green-C")
    end

    # FIXME: Update with new GLX data
    for stop_id <- ["place-river", "place-unsqu"] do
      assert terminus?(stop_id, "Green-D")
    end

    # As of Aug 2022, the Green Line Union Square branch is temporarily suspended.
    # for stop_id <- ["place-unsqu", "place-hsmnl"] do
    for stop_id <- ["place-lech", "place-hsmnl"] do
      assert terminus?(stop_id, "Green-E")
    end
  end

  test "terminus?/3" do
    assert terminus?("place-lake", "Green-B", 0)
    refute terminus?("place-lake", "Green-B", 1)
    # As of Aug 2022, the Green Line Union Square branch is temporarily suspended.
    # refute terminus?("place-unsqu", "Green-E", 0)
    # assert terminus?("place-unsqu", "Green-E", 1)
    refute terminus?("place-lech", "Green-E", 0)
    assert terminus?("place-lech", "Green-E", 1)
  end

  describe "naive_headsign/2" do
    test "correct headsign for route and direction" do
      assert naive_headsign("Green-B", 0) == "Boston College"
      assert naive_headsign("Green-B", 1) == "Government Center"
      assert naive_headsign("Green-C", 0) == "Cleveland Circle"
      assert naive_headsign("Green-C", 1) == "Government Center"
      assert naive_headsign("Green-D", 0) == "Riverside"
      assert naive_headsign("Green-D", 1) == "Union Square"
      assert naive_headsign("Green-E", 0) == "Heath Street"
      # As of Aug 2022, the Green Line Union Square branch is temporarily suspended.
      # assert naive_headsign("Green-E", 1) == "Union Square"
      assert naive_headsign("Green-E", 1) == "Lechmere"
    end
  end

  describe "route_for_stops/1" do
    @stops_on_routes %{
      "Green-B" => ["shared_stop1", "shared_stop2", "b_stop1", "b_stop2"],
      "Green-C" => ["shared_stop1", "shared_stop2", "c_stop1", "c_stop2"]
    }

    test "Returns a map of stop ids associated with the green line routes that stop at that stop" do
      stop_map = routes_for_stops({nil, @stops_on_routes})
      assert "Green-C" in stop_map["shared_stop1"] and "Green-B" in stop_map["shared_stop1"]
      assert "Green-C" in stop_map["shared_stop2"] and "Green-B" in stop_map["shared_stop2"]
      assert stop_map["b_stop2"] == ["Green-B"]
      assert stop_map["c_stop1"] == ["Green-C"]
    end
  end

  describe "filter_lines/2" do
    test "returns error when there is an error" do
      assert filter_lines({:error, "error"}, "Green-B") == {:error, "error"}
    end

    test "returns the list of all stops on a branch in reverse order" do
      stops =
        "Green-B"
        |> Stops.Repo.by_route(0, [])
        |> filter_lines("Green-B")
        |> Enum.map(fn %Stops.Stop{id: id} -> id end)

      assert List.first(stops) == "place-gover"
      assert List.last(stops) == "place-lake"
    end
  end
end
