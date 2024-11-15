defmodule Stops.NearbyTest do
  use ExUnit.Case, async: true
  doctest Stops.Nearby

  import Mox
  import Stops.Nearby
  import Test.Support.Factories.MBTA.Api

  alias Util.Distance

  @latitude 42.577
  @longitude -71.225
  @position {@latitude, @longitude}

  setup :verify_on_exit!

  describe "nearby_with_varying_radius_by_mode/2" do
    test "gets CR/subway/bus stops, gathers then, and fetches them" do
      # assert stops were fetched
      commuter = random_stops(5)
      subway = random_stops(5)
      bus = random_stops(5)

      stub(Stops.Repo.Mock, :get_parent, fn id ->
        Enum.find(commuter ++ subway ++ bus, &(&1.id == id))
      end)

      route_type_map = %{
        "0,1" => subway,
        2 => commuter,
        3 => bus
      }

      api_fn = fn _, opts -> route_type_map[opts[:route_type]] end
      keys_fn = fn %{id: id} -> [id] end

      actual =
        nearby_with_varying_radius_by_mode(@position,
          api_fn: api_fn,
          keys_fn: keys_fn
        )

      expected =
        @position
        |> gather_stops(commuter, subway, bus)

      assert expected == actual
    end

    test "does not include more than two bus stops with a given key" do
      stub(Stops.Repo.Mock, :get_parent, fn id -> id end)

      bus = [
        %{id: 1, latitude: @latitude, longitude: @longitude, keys: [1, 2]},
        %{id: 2, latitude: @latitude, longitude: @longitude, keys: [1]},
        %{id: 3, latitude: @latitude, longitude: @longitude, keys: [1]},
        %{id: 4, latitude: @latitude, longitude: @latitude, keys: [2]}
      ]

      api_fn = fn _, opts -> if opts[:route_type] == 3, do: bus, else: [] end
      keys_fn = fn %{keys: keys} -> keys end

      actual =
        nearby_with_varying_radius_by_mode(@position,
          api_fn: api_fn,
          keys_fn: keys_fn
        )

      expected = [1, 2, 4]

      assert expected == actual
    end

    test "does not include more than one subway stop with a given key" do
      stub(Stops.Repo.Mock, :get_parent, fn id -> id end)

      subway = [
        %{id: 1, latitude: @latitude, longitude: @longitude, keys: [1, 2]},
        %{id: 2, latitude: @latitude, longitude: @longitude, keys: [1]},
        %{id: 3, latitude: @latitude, longitude: @latitude, keys: [2]}
      ]

      api_fn = fn _, opts -> if opts[:route_type] == "0,1", do: subway, else: [] end
      keys_fn = fn %{keys: keys} -> keys end

      actual =
        nearby_with_varying_radius_by_mode(@position,
          api_fn: api_fn,
          keys_fn: keys_fn
        )

      expected = [1]

      assert expected == actual
    end
  end

  describe "api_around/2" do
    test "returns positions around a lat/long" do
      radius = :rand.uniform()

      expect(MBTA.Api.Mock, :get_json, fn path, args ->
        assert path == "/stops/"
        assert args[:sort] == "distance"
        assert args[:radius] == radius
        assert args[:latitude] == @latitude
        assert args[:longitude] == @longitude
        assert args[:include] == "parent_station"

        %JsonApi{data: build_list(3, :stop_item)}
      end)

      [result | _] = api_around(@position, radius: radius)
      assert result
      assert Map.has_key?(result, :id)
      assert Map.has_key?(result, :latitude)
      assert Map.has_key?(result, :longitude)
    end
  end

  describe "keys/1" do
    @describetag :external
    test "returns a list of {route_id, direction_id} tuples" do
      actual = %{id: "place-kencl"} |> keys |> Enum.sort()

      expected = [
        {"19", 0},
        {"19", 1},
        {"57", 0},
        {"57", 1},
        {"60", 0},
        {"60", 1},
        {"65", 0},
        {"65", 1},
        {"8", 0},
        {"8", 1},
        {"9", 1},
        {"Green-B", 0},
        {"Green-B", 1},
        {"Green-C", 0},
        {"Green-C", 1},
        {"Green-D", 0},
        {"Green-D", 1}
      ]

      assert expected == actual
    end

    @tag :external
    test "returns one direction of stops if that's all there is" do
      actual = %{id: "46"} |> keys |> Enum.sort()
      expected = [{"10", 1}]

      assert expected == actual
    end
  end

  describe "gather_stops/4" do
    test "given no results, returns an empty list" do
      assert gather_stops(@position, [], [], []) == []
    end

    test "if there are no CR or Bus stops, takes the 12 closest subway" do
      subway = random_stops(20)

      actual = gather_stops(@position, [], subway, [])
      assert Distance.closest(subway, @position, 12) == actual
    end

    test "if there are no Subway or Bus stops, takes the 4 closest CR" do
      commuter = random_stops(10)

      actual = gather_stops(@position, commuter, [], [])
      assert Distance.closest(commuter, @position, 4) == actual
    end

    test "if subway and CR stops overlap, does not return duplicates" do
      both = random_stops(20)

      actual = gather_stops(@position, both, both, [])
      assert Distance.closest(both, @position, 12) == actual
    end

    test "if non-closest subway and CR stops overlap, does not return duplicates" do
      commuter = random_stops(1)
      subway = [%{id: "very close", latitude: @latitude, longitude: @longitude}]

      actual = gather_stops(@position, commuter, subway ++ commuter, [])
      assert [_, _] = actual
    end

    test "returns 12 closest bus stops" do
      bus = random_stops(20)

      actual = gather_stops(@position, [], [], bus)
      assert Distance.closest(bus, @position, 12) == actual
    end

    test "with subway and commuter, returns 8 bus stops" do
      commuter = random_stops(10)
      subway = random_stops(10)
      bus = random_stops(10)

      actual = gather_stops(@position, commuter, subway, bus)

      assert length(actual) == 12

      for stop <- Distance.closest(bus, @position, 8) do
        assert stop in actual
      end

      assert (commuter |> Distance.closest(@position, 1) |> List.first()) in actual
      assert (subway |> Distance.closest(@position, 1) |> List.first()) in actual
    end

    test "without enough bus stops, fill with subway" do
      commuter = random_stops(10)
      subway = random_stops(10)
      bus = random_stops(4)

      actual = gather_stops(@position, commuter, subway, bus)

      assert length(actual) == 12
    end

    test "basic properties" do
      for _ <- 1..100 do
        stops = random_stops(30)
        commuter = Enum.take_random(stops, Enum.random(0..10))
        subway = Enum.take_random(stops, Enum.random(0..10))
        bus = Enum.take_random(stops, Enum.random(0..10))

        actual = gather_stops(@position, commuter, subway, bus)

        # returns results if there are inputs
        if [] == commuter ++ subway ++ bus do
          assert actual == []
        else
          refute actual == []
        end

        # globally sorted
        assert Distance.sort(actual, @position) == actual
        # no duplicates
        assert Enum.uniq(actual) == actual
        # no more than 12 items
        assert length(actual) <= 12
      end
    end
  end

  def random_stops(count) do
    Enum.map(1..count, fn _ -> random_stop() end)
  end

  defp random_stop do
    id = System.unique_integer() |> Integer.to_string()

    %Stops.Stop{
      id: id,
      name: "Stop #{id}",
      latitude: random_around(@latitude),
      longitude: random_around(@longitude)
    }
  end

  defp random_around(float, range \\ 10_000) do
    integer = :rand.uniform(range * 2) - range
    float + integer / range
  end
end
