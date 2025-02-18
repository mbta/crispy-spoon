defmodule DotcomWeb.Components.RouteSymbolsTest do
  @moduledoc false
  use ExUnit.Case

  import Phoenix.LiveViewTest
  import DotcomWeb.Components.RouteSymbols
  import Test.Support.Factories.Routes.Route

  describe "route_symbol/1" do
    test "supports size variant" do
      route = build(:route)

      assert render_component(&route_symbol/1, %{route: route, size: :default}) !=
               render_component(&route_symbol/1, %{route: route, size: :small})
    end

    test "handles Logan Express, falling back to generic shuttle bus" do
      assert render_component(&route_symbol/1, %{
               route: build(:logan_express_route)
             })
             |> matches_title?("Logan Express")

      assert render_component(&route_symbol/1, %{
               route: build(:logan_express_route, name: "unknown")
             })
             |> matches_title?("Shuttle Bus")
    end

    test "handles Massport, falling back to generic shuttle bus" do
      assert render_component(&route_symbol/1, %{
               route: build(:massport_route)
             })
             |> matches_title?("Massport")

      assert render_component(&route_symbol/1, %{
               route: build(:massport_route, name: "unknown")
             })
             |> matches_title?("Shuttle Bus")
    end

    test "handles buses" do
      route = build(:bus_route)

      assert render_component(&route_symbol/1, %{
               route: route
             }) =~ route.name
    end

    test "handles Silver Live rapid transit" do
      route =
        build(:bus_route,
          description: :rapid_transit,
          id: Faker.Util.pick(Routes.Route.silver_line())
        )

      assert render_component(&route_symbol/1, %{
               route: route
             })
             |> matches_title?("Silver Line")
    end

    test "handles Silver Live buses" do
      route =
        build(:bus_route,
          id: Faker.Util.pick(Routes.Route.silver_line())
        )

      assert render_component(&route_symbol/1, %{
               route: route
             }) =~ route.name
    end

    test "handles rail replacement buses" do
      replaced_route = Faker.Util.pick(~w(Red Orange Blue Green Worcester))
      route_name = replaced_route <> " Line Shuttle"

      route =
        build(:bus_route,
          description: :rail_replacement_bus,
          name: route_name
        )

      icon =
        render_component(&route_symbol/1, %{
          route: route
        })

      assert icon |> matches_title?("Shuttle Bus")
      classnames = icon |> Floki.attribute("class") |> List.first()

      assert classnames =~ "text-#{String.downcase(replaced_route)}-line" ||
               classnames =~ "text-commuter-rail"
    end
  end

  describe "route_icon/1" do
    test "supports size variant" do
      route = build(:route)

      assert render_component(&route_icon/1, %{route: route, size: :default}) !=
               render_component(&route_icon/1, %{route: route, size: :small})
    end
  end

  describe "subway_route_pill/1" do
    test "Subway lines render one element" do
      for route_id <- Dotcom.Routes.subway_line_ids() do
        html =
          render_component(&subway_route_pill/1, %{
            route_ids: [route_id]
          })
          |> Floki.parse_fragment!()
          |> List.first()

        assert html
        assert Floki.children(html, include_text: false) == []
      end
    end

    test "Mattapan renders pill + icon" do
      html =
        render_component(&subway_route_pill/1, %{
          route_ids: ["Mattapan"]
        })
        |> Floki.parse_fragment!()
        |> List.first()

      assert [{"div", _, _}, {"svg", _, _}] = Floki.children(html, include_text: false)
    end

    test "Multiple branches render pill + multiple icons" do
      num_branches = Faker.Util.pick([2, 3])

      html =
        render_component(&subway_route_pill/1, %{
          route_ids: Enum.take(GreenLine.branch_ids(), num_branches)
        })
        |> Floki.parse_fragment!()
        |> List.first()

      assert [{"div", _, _} | icons] = Floki.children(html, include_text: false)
      assert [{"svg", _, _} | _] = icons
      assert Enum.count(icons) == num_branches
    end

    test "List of all Green Line branches renders one pill" do
      all_gl_branches_pill =
        render_component(&subway_route_pill/1, %{
          route_ids: GreenLine.branch_ids()
        })

      green_line_pill =
        render_component(&subway_route_pill/1, %{
          route_ids: ["Green"]
        })

      assert all_gl_branches_pill == green_line_pill
    end
  end

  defp matches_title?(html, text) do
    title =
      html
      |> Floki.find("title")
      |> Floki.text()
      |> String.trim()

    text
    |> Regex.compile!("i")
    |> Regex.match?(title)
  end
end
