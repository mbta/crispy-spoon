defmodule Dotcom.TripPlan.LocationTest do
  use ExUnit.Case, async: true

  import Mox
  import Test.Support.Factories.LocationService.LocationService

  alias Dotcom.TripPlan.{Location, NamedPosition, Query}

  setup :verify_on_exit!

  setup do
    stub(LocationService.Mock, :geocode, fn query ->
      {:ok, build_list(1, :address, %{formatted: query})}
    end)

    :ok
  end

  describe "validate/2" do
    test "sets :to to a NamedPosition when lat/lng are valid floats" do
      params = %{
        "to_latitude" => "42.5678",
        "to_longitude" => "-71.2345",
        "to_stop_id" => "",
        "to" => "To Location"
      }

      assert Location.validate(%Query{}, params) == %Query{
               to: %NamedPosition{
                 latitude: 42.5678,
                 longitude: -71.2345,
                 stop: nil,
                 name: "To Location"
               }
             }
    end

    test "encodes name of a NamedPosition when lat/lng are valid floats" do
      params = %{
        "to_latitude" => "42.5678",
        "to_longitude" => "-71.2345",
        "to" => "To Location's &<script>alert(1)</script>"
      }

      assert Location.validate(%Query{}, params) == %Query{
               to: %NamedPosition{
                 latitude: 42.5678,
                 longitude: -71.2345,
                 name: "To Location's &&lt;script&gt;alert(1)&lt;/script&gt;"
               }
             }
    end

    test "sets :to to a NamedPosition when lat/lng are missing but address is valid" do
      assert %Query{
               to: %NamedPosition{
                 latitude: lat,
                 longitude: lng,
                 name: "10 Park Plaza, Boston MA"
               }
             } = Location.validate(%Query{}, %{"to" => "10 Park Plaza, Boston MA"})

      assert lat
      assert lng
    end

    test "sets :from to a NamedPosition when lat/lng are valid floats" do
      params = %{
        "from_latitude" => "42.5678",
        "from_longitude" => "-71.2345",
        "from_stop_id" => "",
        "from" => "From Location"
      }

      assert Location.validate(%Query{}, params) == %Query{
               from: %NamedPosition{
                 latitude: 42.5678,
                 longitude: -71.2345,
                 stop: nil,
                 name: "From Location"
               }
             }
    end

    test "sets :from to a NamedPosition when lat/lng are missing but address is valid" do
      result = Location.validate(%Query{}, %{"from" => "10 Park Plaza, Boston MA"})
      assert %Query{} = result
      assert %NamedPosition{name: "10 Park Plaza, Boston MA"} = result.from
      assert result.from.latitude
      assert result.from.longitude
    end

    test "handles lat/lng being set to nil" do
      result =
        Location.validate(%Query{}, %{
          "from" => "10 Park Plaza, Boston MA",
          "from_latitude" => "42.5678",
          "from_longitude" => "-71.2345",
          "to" => "20 Park Plaza, Boston MA",
          "to_latitude" => nil,
          "to_longitude" => nil
        })

      assert %Query{} = result
      assert %NamedPosition{} = result.from
      assert "42." <> _ = Float.to_string(result.from.latitude)
      assert "-71." <> _ = Float.to_string(result.from.longitude)
      assert %NamedPosition{name: "20 Park Plaza, Boston MA"} = result.to
      assert result.to.latitude
      assert result.to.longitude
    end

    test "sets :to to {:error, :invalid} when geolocation returns no results" do
      expect(LocationService.Mock, :geocode, fn _ ->
        {:error, :zero_results}
      end)

      result = Location.validate(%Query{}, %{"to" => "no results"})
      assert %Query{} = result
      assert result.to == {:error, :zero_results}
      assert MapSet.member?(result.errors, :zero_results)
    end

    test "sets :from to {:error, :invalid} when geolocation returns no results" do
      expect(LocationService.Mock, :geocode, fn _ ->
        {:error, :zero_results}
      end)

      result = Location.validate(%Query{}, %{"from" => "no results"})
      assert %Query{} = result
      assert result.from == {:error, :zero_results}
      assert MapSet.member?(result.errors, :zero_results)
    end

    test "sets stopID to null if no value in param map" do
      result =
        Location.validate(%Query{}, %{
          "from_latitude" => "42.5678",
          "from_longitude" => "-71.2345",
          "from_stop_id" => "",
          "from" => "From Location"
        })

      assert nil == result.from.stop
    end

    test "sets :same_address error if from and to params are same" do
      result =
        Location.validate(%Query{}, %{
          "from_latitude" => "42.5678",
          "from_longitude" => "-71.2345",
          "from_stop_id" => "",
          "from" => "Location",
          "to_latitude" => "42.5678",
          "to_longitude" => "-71.2345",
          "to_stop_id" => "",
          "to" => "Location"
        })

      assert result.errors == MapSet.new([:same_address])
    end

    test "sets :same_address error if from and to are same" do
      result =
        Location.validate(
          %Query{
            from: %NamedPosition{latitude: 42.5678, longitude: -71.2345},
            to: %NamedPosition{latitude: 42.5678, longitude: -71.2345}
          },
          %{}
        )

      assert result.errors == MapSet.new([:same_address])
    end
  end
end
