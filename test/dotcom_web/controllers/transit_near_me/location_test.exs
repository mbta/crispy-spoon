defmodule DotcomWeb.TransitNearMeController.LocationTest do
  use ExUnit.Case, async: true

  import Mox
  import Test.Support.Factories.LocationService.LocationService

  alias DotcomWeb.TransitNearMeController.Location

  setup :verify_on_exit!

  describe "get/1" do
    test "can take unnested lat/lng values" do
      params = %{
        "latitude" => "#{Faker.Address.latitude()}",
        "longitude" => "#{Faker.Address.longitude()}",
        "location" => %{
          "address" => Faker.Address.street_address()
        }
      }

      assert Location.get(params)
    end

    test "does not attempt any geocoding if all params are provided" do
      params = %{
        "location" => %{
          "latitude" => "#{Faker.Address.latitude()}",
          "longitude" => "#{Faker.Address.longitude()}",
          "address" => Faker.Address.street_address()
        }
      }

      assert Location.get(params)
    end

    test "geocodes address if lat/lng is not provided" do
      address = Faker.Address.street_address()

      expect(LocationService.Mock, :geocode, fn ^address ->
        {:ok, []}
      end)

      params = %{
        "location" => %{
          "address" => address
        }
      }

      assert Location.get(params)
    end

    test "geocodes address if lat/lng is nil" do
      address = Faker.Address.street_address()

      expect(LocationService.Mock, :geocode, fn ^address ->
        {:ok, []}
      end)

      params = %{
        "location" => %{
          "latitude" => "#{Faker.Address.latitude()}",
          "longitude" => nil,
          "address" => address
        }
      }

      assert Location.get(params)
    end

    test "geocodes address from param" do
      address = Faker.Address.street_address()

      expect(LocationService.Mock, :geocode, fn ^address ->
        {:ok, []}
      end)

      params = %{
        "address" => address
      }

      assert Location.get(params)
    end

    test "geocodes address if lat/lng are not floats" do
      address = Faker.Address.street_address()

      expect(LocationService.Mock, :geocode, fn ^address ->
        {:ok, []}
      end)

      params = %{
        "location" => %{
          "latitude" => "",
          "longitude" => "",
          "address" => address
        }
      }

      assert Location.get(params)
    end

    test "reverse geocodes lat/lng if address is not provided" do
      latitude = Faker.Address.latitude()
      longitude = Faker.Address.longitude()

      params = %{
        "location" => %{
          "latitude" => "#{latitude}",
          "longitude" => "#{longitude}"
        }
      }

      expect(LocationService.Mock, :reverse_geocode, fn ^latitude, ^longitude ->
        {:ok, build_list(2, :address)}
      end)

      assert Location.get(params)
    end

    test "returns an error if there is an error with reverse geocoding" do
      expect(LocationService.Mock, :reverse_geocode, fn _, _ ->
        {:error, :internal_error}
      end)

      params = %{
        "location" => %{
          "latitude" => "0.0",
          "longitude" => "0.0"
        }
      }

      assert Location.get(params) == {:error, :internal_error}
    end

    test "returns :no_address if params don't include address or lat/lng" do
      assert Location.get(%{}) == :no_address
    end
  end
end
