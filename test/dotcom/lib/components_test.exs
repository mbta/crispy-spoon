defmodule Dotcom.ComponentsTest do
  use DotcomWeb.ConnCase, async: true
  use Dotcom.Components.Precompiler

  import Phoenix.HTML, only: [safe_to_string: 1]

  alias Dotcom.Components.Buttons.ButtonGroup
  alias Dotcom.Components.Icons.SvgIcon
  alias Dotcom.Components.Tabs.ModeTabList

  describe "buttons > button_group" do
    test "button list renders links in button containers" do
      rendered =
        %ButtonGroup{links: [{"Link 1", "/link-1"}, {"Link 2", "/link-2"}]}
        |> button_group()
        |> safe_to_string()

      assert [{"div", [{"class", "button-group"}], links}] = Floki.find(rendered, ".button-group")

      for link <- links do
        assert Floki.attribute(link, "class") == ["button-container"]
      end
    end
  end

  describe "icons > svg_icon" do
    test "raises an error if icon not found" do
      assert_raise RuntimeError, "fail icon not found", fn -> svg_icon(%SvgIcon{icon: :fail}) end
    end

    test "icon can take multiple argument types and render the correct atom" do
      bus = svg_icon(%SvgIcon{icon: :bus})
      assert svg_icon(%SvgIcon{icon: %Routes.Route{type: 3}}) == bus
      assert svg_icon(%SvgIcon{icon: 3}) == bus
      red_line = svg_icon(%SvgIcon{icon: :red_line})
      mattapan_line = svg_icon(%SvgIcon{icon: :mattapan_line})
      assert svg_icon(%SvgIcon{icon: %Routes.Route{type: 0, id: "Mattapan"}}) == mattapan_line
      assert svg_icon(%SvgIcon{icon: %Routes.Route{type: 1, id: "Red"}}) == red_line
      assert svg_icon(%SvgIcon{icon: "Escalator"}) == svg_icon(%SvgIcon{icon: :access})
    end

    test "icons render an svg with correct classes" do
      rendered = %SvgIcon{icon: :map} |> svg_icon |> safe_to_string
      assert rendered =~ "</svg>"
      assert rendered =~ "icon-map"
      assert rendered =~ "icon "
    end

    test "icons do not render with a background circle" do
      rendered = %SvgIcon{icon: :subway} |> svg_icon |> safe_to_string
      assert rendered =~ "icon-subway"
      assert rendered =~ "icon "
      refute rendered =~ "icon-circle"
    end

    test "alert icons have an accessible title" do
      rendered = %SvgIcon{icon: :alert} |> svg_icon |> safe_to_string
      assert rendered =~ "Service alert or delay"
    end

    test "Title tooltip is shown if show_tooltip? is not specified" do
      rendered = %SvgIcon{icon: :subway} |> svg_icon() |> safe_to_string()

      [data_toggle] =
        rendered |> Floki.find("svg") |> List.first() |> Floki.attribute("data-toggle")

      assert data_toggle == "tooltip"
    end

    test "Tooltip is not shown if show_tooltip? is false" do
      rendered = %SvgIcon{icon: :subway, show_tooltip?: false} |> svg_icon() |> safe_to_string()
      assert rendered |> Floki.find("svg") |> List.first() |> Floki.attribute("data-toggle") == []
    end
  end

  describe "tabs > mode_tab_list" do
    @links [
      {"commuter-rail", "/commuter-rail"},
      {"bus", "/bus"},
      {"subway", "/subway"},
      {"the_ride", "/the-ride"},
      {"access", "/access"}
    ]

    def mode_tab_args do
      %ModeTabList{
        class: "navbar-toggleable-sm",
        links: @links,
        selected_mode: :bus
      }
    end

    test "renders a list of tabs for with links for modes, including access and the ride" do
      rendered = mode_tab_args() |> mode_tab_list() |> safe_to_string()

      for link <- [
            "/commuter-rail#commuter-rail-tab",
            "/bus#bus-tab",
            "/subway#subway-tab",
            "/the-ride#the-ride-tab",
            "/access#access-tab"
          ] do
        assert rendered =~ ~s(href="#{link}")
      end
    end

    test "displays the selected tab as such" do
      rendered = mode_tab_args() |> mode_tab_list() |> safe_to_string()
      assert rendered =~ "tab-select-btn-selected"
    end

    test "renders icons for each mode" do
      rendered = mode_tab_args() |> mode_tab_list() |> safe_to_string()

      for mode <- ["bus", "subway"] do
        assert rendered =~ "icon-mode-#{mode}"
      end

      for icon <- ["the-ride", "accessible"] do
        assert rendered =~ "icon-#{icon}"
      end
    end

    test "mode_links/1" do
      expected = [
        {"commuter_rail", "Commuter Rail", "/commuter-rail"},
        {"bus", "Bus", "/bus"},
        {"subway", "Subway", "/subway"},
        {"the_ride", "The Ride", "/the-ride"},
        {"access", "Access", "/access"}
      ]

      assert mode_links(@links) == expected
    end

    test "build_icon_map/2" do
      icon_map = build_mode_icon_map(@links)
      assert safe_to_string(icon_map["Subway"]) =~ "icon-mode-subway"
      assert safe_to_string(icon_map["Bus"]) =~ "icon-mode-bus"
    end
  end

  describe "tabs > tab_selector" do
    @links [
      {"sched", "Schedules", "/schedules"},
      {"info", "Info", "/info"},
      {"etc", "Something Else", "/something-else"}
    ]

    def tab_args do
      %TabSelector{
        links: @links,
        selected: "info",
        icon_map: %{"Info" => "info-icon"}
      }
    end

    test "renders a list of tabs" do
      rendered = tab_args() |> tab_selector() |> safe_to_string()

      for link <- [
            "/schedules#schedules-tab",
            "/info#info-tab",
            "/something-else#something-else-tab"
          ] do
        assert rendered =~ ~s(href="#{link}")
      end
    end

    test "displays a tab as selected" do
      rendered = tab_args() |> tab_selector() |> safe_to_string()

      assert rendered =~ ~r/<a.*href=\"\/info#info-tab\"/
      assert rendered =~ ~r/class=.*tab-select-btn-selected/
    end

    test "optionally takes a CSS class" do
      rendered = tab_args() |> Map.put(:class, "test-class") |> tab_selector() |> safe_to_string()

      assert rendered =~ "test-class"
    end

    test "Icons are shown if given" do
      rendered = tab_args() |> tab_selector() |> safe_to_string()

      option =
        rendered
        |> Floki.find(".tab-select-btn-selected")
        |> Enum.at(0)
        |> elem(2)
        |> List.first()

      assert option =~ "info-icon"
    end

    test "Selected option is shown as such" do
      rendered = tab_args() |> tab_selector() |> safe_to_string()

      option =
        rendered
        |> Floki.find(".tab-select-btn-selected")

      assert inspect(option) =~ "Info"
    end

    test "selected?/2" do
      assert selected?("info", "info")
      refute selected?("schedules", "info")
    end
  end

  describe "get_path/1" do
    test "can take a %Route{}" do
      assert %Routes.Route{id: "Red"}
             |> get_path()
             |> safe_to_string() =~ "<path"
    end

    test "returns bus icon path for massport routes" do
      expected = get_path(:bus)
      assert expected == get_path(:logan_express)
      assert expected == get_path(:massport_shuttle)
    end
  end

  def current_active_period do
    [period_shift(minutes: -5), period_shift(minutes: 5)]
  end

  defp period_shift(period) do
    {Util.now() |> Timex.shift(period), nil}
  end
end
