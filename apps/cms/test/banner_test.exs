defmodule Content.BannerTest do
  use ExUnit.Case, async: true

  setup do
    api_notices = Content.CMS.Static.banners_response()
    %{api_notices: api_notices}
  end

  test "it parses the API response into a Content.Banner struct", %{api_notices: [raw | _]} do
    assert Map.get(raw, "field_text_position") == []
    assert Map.get(raw, "field_banner_type") == [%{"value" => "important"}]

    assert Map.get(raw, "field_page_type") == [
             %{"data" => nil, "id" => 248, "name" => "Careers", "vocab" => "page_type"}
           ]

    assert Map.get(raw, "field_mode") == [%{"value" => "commuter_rail"}]
    assert Map.get(raw, "field_updated_on") == [%{"value" => "2018-09-25"}]
    assert Map.get(raw, "title") == [%{"value" => "Headline goes here"}]

    assert %Content.Banner{
             blurb: blurb,
             link: %Content.Field.Link{url: url},
             thumb: %Content.Field.Image{},
             text_position: text_position,
             banner_type: banner_type,
             category: category,
             routes: routes,
             updated_on: updated_on,
             title: title
           } = Content.Banner.from_api(raw)

    assert blurb == "Headline goes here"
    assert url == "/"
    assert text_position == :left
    assert banner_type == :important
    assert category == "Careers"
    assert updated_on == "September 25, 2018"
    assert title == "Headline goes here"
    assert [%{mode: "commuter_rail"}] = routes
  end

  test "it parses fields for a default banner", %{api_notices: [_, raw]} do
    assert Map.get(raw, "field_text_position") == [%{"value" => "right"}]
    assert Map.get(raw, "field_banner_type") == [%{"value" => "default"}]

    assert Map.get(raw, "field_page_type") == [
             %{"data" => nil, "id" => 248, "name" => "Guides", "vocab" => "page_type"}
           ]

    assert [%{"name" => "CR-Franklin"}] = Map.get(raw, "field_related_transit")
    assert Map.get(raw, "field_updated_on") == [%{"value" => "2018-10-01"}]
    assert Map.get(raw, "title") == [%{"value" => "Commuter Rail Guide"}]

    assert %Content.Banner{
             blurb: blurb,
             link: %Content.Field.Link{url: url},
             thumb: %Content.Field.Image{},
             text_position: text_position,
             banner_type: banner_type,
             category: category,
             routes: routes,
             updated_on: updated_on,
             title: title
           } = Content.Banner.from_api(raw)

    assert blurb == "This is the description of the commuter rail guide"
    assert url == "/node/3791"
    assert text_position == :right
    assert banner_type == :default
    assert category == "Guides"
    assert updated_on == "October 1, 2018"
    assert title == "Commuter Rail Guide"
    assert [%{mode: "commuter_rail"}] = routes
  end

  test "handles missing values without crashing" do
    assert %Content.Banner{
             blurb: blurb,
             link: nil,
             thumb: nil,
             text_position: text_position,
             banner_type: banner_type,
             category: category,
             routes: routes,
             updated_on: updated_on,
             title: title
           } = Content.Banner.from_api(%{})

    assert blurb == ""
    assert text_position == :left
    assert banner_type == :default
    assert category == ""
    assert updated_on == ""
    assert title == ""
    assert routes == []
  end

  test "it prefers field_image media image values, if present", %{api_notices: [_, data | _]} do
    assert %Content.Banner{
             thumb: %Content.Field.Image{
               alt: thumb_alt,
               url: thumb_url
             }
           } = Content.Banner.from_api(data)

    assert thumb_alt == "Commuter Rail train crossing a bridge in Ashland"

    assert thumb_url =~
             "http://localhost:4002/sites/default/files/styles/important_notice/public/media/2018-09/P519%20Ashland_retouch.jpg?itok=5NKSY_ts"
  end
end
