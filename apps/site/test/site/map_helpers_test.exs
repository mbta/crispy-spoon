defmodule MapHelpersTest do
  use SiteWeb.ConnCase, async: true
  import Site.MapHelpers

  describe "map_pdf_url/1" do
    test "returns a URL string" do
      map_types = [:subway, :ferry, :bus, :commuter_rail]

      for map_type <- map_types do
        assert map_type |> map_pdf_url() |> is_binary()
        refute map_type == ""
      end
    end
  end

  describe "thumbnail/1" do
    test "returns a map image url for the subway" do
      assert thumbnail(:subway) ==
               static_url(SiteWeb.Endpoint, "/images/map-thumbnail-subway.jpg")
    end

    test "returns a map image url for the bus" do
      assert thumbnail(:bus) ==
               static_url(SiteWeb.Endpoint, "/images/map-thumbnail-bus-system.jpg")
    end

    test "returns a map image url for the commuter rail" do
      assert thumbnail(:commuter_rail) ==
               static_url(SiteWeb.Endpoint, "/images/map-thumbnail-commuter-rail.jpg")
    end

    test "returns a map image url for the commuter rail zones" do
      assert thumbnail(:commuter_rail_zones) ==
               static_url(SiteWeb.Endpoint, "/images/map-thumbnail-fare-zones.jpg")
    end

    test "returns a map image url for the ferry" do
      assert thumbnail(:ferry) == static_url(SiteWeb.Endpoint, "/images/map-thumbnail-ferry.jpg")
    end
  end

  describe "map_stop_icon_path" do
    test "returns correct path when size is not :mid" do
      assert map_stop_icon_path(:tiny) =~ "000000-dot"
    end

    test "returns correct path when size is :mid" do
      assert map_stop_icon_path(:mid) =~ "000000-dot-mid"
    end

    test "returns correct path when 'filled' is specified and size" do
      assert map_stop_icon_path(:mid, true) == "000000-dot-filled-mid"
    end

    test "returns orrect path when 'filled' is true" do
      assert map_stop_icon_path(:tiny, true) == "000000-dot-filled"
    end
  end
end
