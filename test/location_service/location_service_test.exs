defmodule LocationServiceTest do
  use ExUnit.Case, async: true

  import LocationService
  import Mox
  import Test.Support.Factories.AwsClient

  setup :verify_on_exit!

  describe "geocode/1" do
    test "can handle a response with results" do
      address = Faker.Address.street_address()

      expect(AwsClient.Mock, :search_place_index_for_text, fn _, input, _ ->
        assert input[:Text] == address
        response = build(:search_place_index_for_text_response)
        {:ok, response, %{}}
      end)

      assert [%LocationService.Address{} | _] = geocode(address)
    end

    test "can handle a response with error" do
      expect(AwsClient.Mock, :search_place_index_for_text, fn _, _, _ ->
        {:error, "Some error message"}
      end)

      assert {:error, :internal_error} = Faker.Address.street_address() |> geocode()
    end
  end

  describe "reverse_geocode/2" do
    test "can parse a response with results" do
      latitude = Faker.Address.latitude()
      longitude = Faker.Address.longitude()

      expect(AwsClient.Mock, :search_place_index_for_position, fn _, input, _ ->
        assert input[:Position] == [longitude, latitude]
        response = build(:search_place_index_for_position_response)
        {:ok, response, %{}}
      end)

      assert [%LocationService.Address{} | _] = reverse_geocode(latitude, longitude)
    end

    test "can handle a response with error" do
      expect(AwsClient.Mock, :search_place_index_for_position, fn _, _, _ ->
        {:error, "Some error message"}
      end)

      latitude = Faker.Address.latitude()
      longitude = Faker.Address.longitude()
      assert {:error, :internal_error} = reverse_geocode(latitude, longitude)
    end
  end

  describe "autocomplete/2" do
    test "can parse a response with results" do
      text = Faker.Company.name()

      expect(AwsClient.Mock, :search_place_index_for_suggestions, fn _, input, _ ->
        assert input[:Text] == text
        response = build(:search_place_index_for_suggestions_response)
        response = put_in(response["Summary"]["Text"], text)
        {:ok, response, %{}}
      end)

      suggestions = autocomplete(text, 2)
      assert [%LocationService.Suggestion{} | _] = suggestions
    end

    test "can handle a response with error" do
      expect(AwsClient.Mock, :search_place_index_for_suggestions, fn _, _, _ ->
        {:error, "Some error message"}
      end)

      text = Faker.Company.name()
      assert {:error, :internal_error} = autocomplete(text, 2)
    end
  end
end
