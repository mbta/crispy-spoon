defmodule Algolia.ObjectTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, Application.get_env(:algolia, :repos)}
  end

  describe "Algolia.Object.data" do
    test "for Stops.Stop", %{stops: repo} do
      stop = repo.get("place-commuter-rail")
      data = Algolia.Object.data(stop)
      assert data._geoloc == %{lat: stop.latitude, lng: stop.longitude}
      assert data.stop == stop
      assert is_list(data.routes)
      assert data.features == [:access, :parking_lot]
    end

    test "for Routes.Route", %{routes: repo} do
      route = repo.get("CR-Commuterrail")
      data = Algolia.Object.data(route)
      assert data.stop_names == ["Green Line Stop", "Subway Station", "Commuter Rail Stop"]
      assert data.headsigns == ["CR Terminus 1", "CR Terminus 2"]

      assert data.route == %{
               route
               | direction_names: [route.direction_names[0], route.direction_names[1]],
                 direction_destinations: [
                   route.direction_destinations[0],
                   route.direction_destinations[1]
                 ]
             }

      refute Map.has_key?(data, :_geoloc)
    end

    test "for Routes.Route that is a bus route", %{routes: repo} do
      route = repo.get("1000")
      data = Algolia.Object.data(route)
      # Should not include bus stop
      assert data.stop_names == ["Green Line Stop", "Commuter Rail Stop"]
      assert data.headsigns == ["Terminus 1", "Terminus 2"]

      assert data.route == %{
               route
               | direction_names: [route.direction_names[0], route.direction_names[1]],
                 direction_destinations: [
                   route.direction_destinations[0],
                   route.direction_destinations[1]
                 ]
             }

      refute Map.has_key?(data, :_geoloc)
    end
  end

  describe "Algolia.Object.url" do
    test "for Stops.Stop", %{stops: repo} do
      assert "place-commuter-rail"
             |> repo.get()
             |> Algolia.Object.url() == "/stops/place-commuter-rail"
    end

    test "for Routes.Route", %{routes: repo} do
      assert "CR-Commuterrail"
             |> repo.get()
             |> Algolia.Object.url() == "/schedules/CR-Commuterrail"
    end
  end
end
