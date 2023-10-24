defmodule Algolia.Query.RequestTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Algolia.Query.Request

  describe "new/2" do
    test "doesn't work for invalid index" do
      assert Request.new("drupal", "question")
      assert_raise FunctionClauseError, fn -> Request.new("fakeindex", "question") end
    end

    test "includes query" do
      search_string = "asfdsagfsadgsad"
      assert %Request{query: ^search_string} = Request.new("drupal", search_string)
    end

    test "changes hitsPerPage param based on index" do
      assert %Request{params: %{"hitsPerPage" => 5}} = Request.new("routes", "")
      assert %Request{params: %{"hitsPerPage" => 2}} = Request.new("drupal", "")
    end

    test "changes attributesToHighlight param based on index" do
      assert %Request{attributesToHighlight: "stop.name"} = Request.new("stops", "")

      assert %Request{attributesToHighlight: ["route.name", "route.long_name"]} =
               Request.new("routes", "")
    end

    test "changes facetFilters param based on index" do
      assert %Request{params: %{"facetFilters" => [[]]}} = Request.new("routes", "")
      assert %Request{params: %{"facetFilters" => facetFilters}} = Request.new("drupal", "")
      refute facetFilters == [[]]
    end
  end

  test "encode/1 returns a JSON-encodable map with encoded params" do
    request = Request.new("drupal", "some special search")
    encoded = Request.encode(request)

    assert encoded == %{
             "attributesToHighlight" => "content_title",
             "highlightPostTag" => "__/aa-highlight__",
             "highlightPreTag" => "__aa-highlight__",
             "indexName" => "drupal_test",
             "params" =>
               "analytics=false&clickAnalytics=true&facetFilters=%5B%5B%22_content_type%3Apage%22%2C%22_content_type%3Asearch_result%22%2C%22_content_type%3Adiversion%22%2C%22_content_type%3Alanding_page%22%2C%22_content_type%3Aperson%22%2C%22_content_type%3Aproject%22%2C%22_content_type%3Aproject_update%22%5D%5D&facets=%5B%22*%22%5D&hitsPerPage=2",
             "query" => "some special search"
           }
  end
end
