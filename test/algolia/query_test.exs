defmodule Algolia.QueryTest do
  use ExUnit.Case, async: true

  import Test.Support.EnvHelpers

  alias Algolia.Query

  @encoded_query_params [
    "clickAnalytics=true",
    "facetFilters=%5B%5B%22route.type%3A0%22%2C%22route.type%3A1%22%2C%22route.type%3A3%22%2C%22route.type%3A2%22%2C%22route.type%3A4%22%5D%5D",
    "facets=%5B%22*%22%5D",
    "hitsPerPage=5",
    "query=a"
  ]

  @decoded_query %{
    "clickAnalytics" => "true",
    "facets" => ["*"],
    "facetFilters" => [
      [
        "route.type:0",
        "route.type:1",
        "route.type:3",
        "route.type:2",
        "route.type:4"
      ]
    ],
    "hitsPerPage" => "5",
    "query" => "a"
  }

  describe "encode_params/1" do
    test "encodes a query map into a string" do
      assert Query.encode_params(@decoded_query) ==
               Enum.join(["analytics=false" | @encoded_query_params], "&")
    end

    test "adds analytics param if :track_analytics? is true" do
      reassign_env(:dotcom, :algolia_track_analytics?, true)

      assert Query.encode_params(@decoded_query) ==
               Enum.join(["analytics=true" | @encoded_query_params], "&")
    end
  end

  describe "build/1" do
    test "encodes a full query" do
      full_query = %{
        "requests" => [
          %{
            "indexName" => "index",
            "query" => "a",
            "params" => @decoded_query
          }
        ]
      }

      encoded = Query.build(full_query)
      assert {:ok, %{"requests" => [query]}} = Jason.decode(encoded)

      assert %{
               "indexName" => "index",
               "query" => "a",
               "params" => params
             } = query

      assert params == Enum.join(["analytics=false" | @encoded_query_params], "&")
    end

    test "can construct and encode a query" do
      n = Faker.random_between(1, 5)

      encoded =
        Query.build(%{
          "algoliaQuery" => "b",
          "algoliaIndexesWithParams" => %{
            "stops" => %{
              "hitsPerPage" => n
            },
            "routes" => %{}
          }
        })

      assert {:ok, %{"requests" => multiple_queries}} = Jason.decode(encoded)
      assert length(multiple_queries) == 2

      assert %{
               "indexName" => "stops_test",
               "query" => "b",
               "attributesToHighlight" => "stop.name",
               "params" => params
             } = List.first(multiple_queries)

      assert params ==
               "analytics=false&clickAnalytics=true&facetFilters=%5B%5B%5D%5D&facets=%5B%22*%22%5D&hitsPerPage=#{n}"
    end
  end
end
