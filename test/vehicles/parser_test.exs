defmodule Vehicles.ParserTest do
  use ExUnit.Case, async: true

  import Vehicles.Parser

  alias Vehicles.Vehicle

  @item %JsonApi.Item{
    attributes: %{
      "current_status" => "STOPPED_AT",
      "direction_id" => 1,
      "longitude" => 1.1,
      "latitude" => 2.2,
      "bearing" => 140
    },
    id: "y1799",
    relationships: %{
      "route" => [%JsonApi.Item{id: "1"}],
      "stop" => [%JsonApi.Item{id: "72"}],
      "trip" => [%JsonApi.Item{id: "25"}]
    },
    type: "vehicle"
  }

  describe "parse/1" do
    test "parses an API response into a Vehicle struct" do
      expected = %Vehicle{
        id: "y1799",
        route_id: "1",
        stop_id: "72",
        trip_id: "25",
        direction_id: 1,
        status: :stopped,
        latitude: 2.2,
        longitude: 1.1,
        bearing: 140
      }

      assert parse(@item) == expected
    end

    test "can handle a missing trip" do
      item = put_in(@item.relationships["trip"], [])

      expected = %Vehicle{
        id: "y1799",
        route_id: "1",
        stop_id: "72",
        trip_id: nil,
        direction_id: 1,
        status: :stopped,
        latitude: 2.2,
        longitude: 1.1,
        bearing: 140
      }

      assert parse(item) == expected
    end

    test "can handle a missing stop" do
      item = put_in(@item.relationships["stop"], [])

      expected = %Vehicle{
        id: "y1799",
        route_id: "1",
        stop_id: nil,
        trip_id: "25",
        direction_id: 1,
        status: :stopped,
        latitude: 2.2,
        longitude: 1.1,
        bearing: 140
      }

      assert parse(item) == expected
    end

    test "can handle a missing route" do
      item = put_in(@item.relationships["route"], [])
      # if we don't have a route, we definitely don't have a trip
      item = put_in(item.relationships["trip"], [])

      expected = %Vehicle{
        id: "y1799",
        route_id: nil,
        stop_id: "72",
        trip_id: nil,
        direction_id: 1,
        status: :stopped,
        latitude: 2.2,
        longitude: 1.1,
        bearing: 140
      }

      assert parse(item) == expected
    end

    test "can handle occupancy status" do
      item = put_in(@item.attributes["occupancy_status"], "FEW_SEATS_AVAILABLE")

      expected = %Vehicle{
        id: "y1799",
        route_id: "1",
        stop_id: "72",
        trip_id: "25",
        direction_id: 1,
        status: :stopped,
        latitude: 2.2,
        longitude: 1.1,
        bearing: 140,
        crowding: :some_crowding
      }

      assert parse(item) == expected
    end
  end
end
