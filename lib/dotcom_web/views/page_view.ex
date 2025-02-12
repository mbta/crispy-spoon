defmodule DotcomWeb.PageView do
  @moduledoc false
  import PhoenixHTMLHelpers.Tag
  import DotcomWeb.CMSHelpers
  import DotcomWeb.CMS.ParagraphView, only: [render_paragraph: 2]
  import DotcomWeb.Components.SystemStatus.SubwayStatus, only: [subway_status: 1]

  alias CMS.Page.NewsEntry
  alias CMS.Partial.Banner
  alias DotcomWeb.PartialView

  use DotcomWeb, :view

  @stops_repo Application.compile_env!(:dotcom, :repo_modules)[:stops]
  @spec get_route(Routes.Route.id_t()) :: Routes.Route.t() | nil
  def get_route(id) do
    case DotcomWeb.ScheduleController.Line.Helpers.get_route(id) do
      {:ok, route} -> route
      _ -> nil
    end
  end

  @spec sort_routes({Routes.Route.gtfs_route_type(), [Routes.Route.t()]}) ::
          {Routes.Route.gtfs_route_type(), [Routes.Route.t()]}
  defp sort_routes({mode, routes}) do
    {mode, Enum.sort_by(routes, & &1.sort_order)}
  end

  @spec get_mode_order({Routes.Route.gtfs_route_type(), [Routes.Route.t()]}) :: integer()
  defp get_mode_order({:subway, _}), do: 0
  defp get_mode_order({:bus, _}), do: 1
  defp get_mode_order({:commuter_rail, _}), do: 2
  defp get_mode_order({:ferry, _}), do: 3

  @spec get_access_issue_order({Alerts.Accessibility.effect_type(), [Stops.Stop.t()]}) ::
          integer()
  defp get_access_issue_order({:elevator_closure, _}), do: 0
  defp get_access_issue_order({:escalator_closure, _}), do: 1
  defp get_access_issue_order({:access_issue, _}), do: 2

  @spec alerts([Alerts.Alert.t()]) :: Phoenix.HTML.Safe.t()
  def alerts(alerts) do
    routes_with_high_priority_alerts_by_mode =
      alerts
      |> Enum.filter(&(Alerts.Priority.priority(&1) == :high))
      |> Enum.reduce(MapSet.new(), fn alert, routes ->
        MapSet.union(routes, Alerts.Alert.get_entity(alert, :route))
      end)
      |> Enum.filter(& &1)
      |> Enum.map(&get_route/1)
      |> Enum.filter(& &1)
      |> Enum.group_by(&Routes.Route.type_atom(&1.type))
      |> (&Map.merge(%{bus: [], subway: [], ferry: [], commuter_rail: []}, &1)).()
      |> Enum.map(&sort_routes/1)
      |> Enum.sort_by(&get_mode_order/1)

    stops_with_accessibility_alerts_by_issue =
      alerts
      |> Enum.filter(&Alerts.Accessibility.accessibility?/1)
      |> Enum.reduce(
        Map.new(Alerts.Accessibility.effect_types(), fn t -> {t, MapSet.new()} end),
        fn alert, types ->
          stops = Alerts.Alert.get_entity(alert, :stop)
          type = alert.effect

          Map.put(types, type, MapSet.union(Map.get(types, type), stops))
        end
      )
      |> Enum.map(fn {type, stops} ->
        {type,
         Enum.map(stops, &@stops_repo.get_parent/1)
         |> Enum.filter(& &1)
         |> Enum.uniq_by(& &1.id)
         |> Enum.sort_by(& &1.name)}
      end)
      |> Enum.sort_by(&get_access_issue_order/1)

    render("_alerts.html",
      routes_with_high_priority_alerts_by_mode: routes_with_high_priority_alerts_by_mode,
      stops_with_accessibility_alerts_by_issue: stops_with_accessibility_alerts_by_issue
    )
  end

  @spec alerts_mode_url(Routes.Route.gtfs_route_type()) :: String.t()
  defp alerts_mode_url(mode) do
    path =
      case mode do
        :commuter_rail -> "commuter-rail"
        _ -> mode
      end

    DotcomWeb.Router.Helpers.alert_url(
      DotcomWeb.Endpoint,
      :show,
      path
    )
  end

  @spec alerts_access_url :: String.t()
  defp alerts_access_url do
    DotcomWeb.Router.Helpers.alert_url(
      DotcomWeb.Endpoint,
      :show,
      "access"
    )
  end

  @spec alerts_render_route_link_content(Routes.Route.gtfs_route_type(), Routes.Route.t()) ::
          Phoenix.HTML.Safe.t()
  defp alerts_render_route_link_content(mode, route) do
    case mode do
      :subway -> DotcomWeb.ViewHelpers.line_icon(route, :default)
      :bus -> DotcomWeb.ViewHelpers.bus_icon_pill(route)
      _ -> route.name
    end
  end

  @spec alerts_mode_icon_name(Routes.Route.gtfs_route_desc()) :: String.t()
  defp alerts_mode_icon_name(mode) do
    case mode do
      :subway -> "icon-subway-default.svg"
      :bus -> "icon-bus-default.svg"
      :ferry -> "icon-ferry-default.svg"
      :commuter_rail -> "icon-commuter-rail-default.svg"
    end
  end

  @spec alerts_route_url(Routes.Route.t()) :: String.t()
  defp alerts_route_url(route) do
    DotcomWeb.Router.Helpers.alerts_url(
      DotcomWeb.Endpoint,
      :show,
      route.id
    )
  end

  @spec alerts_stop_url(Stops.Stop.t()) :: String.t()
  defp alerts_stop_url(stop) do
    DotcomWeb.Router.Helpers.stop_url(
      DotcomWeb.Endpoint,
      :show,
      stop.id
    )
  end

  def shortcut_icons do
    [:commuter_rail, :subway, :bus, :ferry, :the_ride]
    |> Enum.map(&shortcut_icon/1)
  end

  @spec shortcut_icon(atom) :: Phoenix.HTML.Safe.t()
  defp shortcut_icon(id) do
    content_tag(
      :a,
      [
        id |> shortcut_svg_name() |> svg(),
        content_tag(:div, shortcut_text(id), class: "m-homepage__shortcut-text")
      ],
      href: shortcut_link(id),
      class: "m-homepage__shortcut"
    )
  end

  @spec shortcut_link(atom) :: String.t()
  defp shortcut_link(:stations), do: stop_path(DotcomWeb.Endpoint, :index)

  defp shortcut_link(:the_ride),
    do: cms_static_page_path(DotcomWeb.Endpoint, "/accessibility/the-ride")

  defp shortcut_link(:commuter_rail),
    do: schedule_path(DotcomWeb.Endpoint, :show, :"commuter-rail")

  defp shortcut_link(mode), do: schedule_path(DotcomWeb.Endpoint, :show, mode)

  @spec shortcut_text(atom) :: [Phoenix.HTML.Safe.t()]
  defp shortcut_text(:stations) do
    [
      "Stations",
      content_tag(:span, " & Stops", class: "hidden-md-down")
    ]
  end

  defp shortcut_text(:the_ride) do
    content_tag(:span, "The RIDE")
  end

  defp shortcut_text(:commuter_rail) do
    content_tag(:span, "Commuter Rail")
  end

  defp shortcut_text(:subway) do
    [
      "Subway",
      content_tag(:span, " Lines", class: "hidden-md-down")
    ]
  end

  defp shortcut_text(mode) do
    [
      mode_name(mode),
      content_tag(:span, " Routes", class: "hidden-md-down")
    ]
  end

  defp shortcut_svg_name(:stations), do: "icon-circle-t-default.svg"
  defp shortcut_svg_name(:the_ride), do: "icon-the-ride-default.svg"
  defp shortcut_svg_name(:commuter_rail), do: shortcut_svg_name(:"commuter-rail")
  defp shortcut_svg_name(mode), do: "icon-mode-#{mode}-default.svg"

  def schedule_separator do
    content_tag(:span, "|", aria_hidden: "true", class: "schedule-separator")
  end

  @spec render_news_entries(Plug.Conn.t()) :: Phoenix.HTML.Safe.t()
  def render_news_entries(conn) do
    content_tag(
      :div,
      conn.assigns
      |> Map.get(:news)
      |> Enum.split(3)
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.map(&do_render_news_entries/1),
      class: "row"
    )
  end

  @spec do_render_news_entries({[NewsEntry.t()], 0 | 1}) ::
          Phoenix.HTML.Safe.t()
  defp do_render_news_entries({entries, idx}) when idx in [0, 1] do
    content_tag(
      :div,
      Enum.map(
        entries,
        &PartialView.news_entry(&1, class: "m-homepage__news-item")
      ),
      class: "col-md-6"
    )
  end

  @spec banner_content_class(Banner.t()) :: String.t()
  defp banner_content_class(%Banner{} = banner) do
    Enum.join(
      [
        "c-banner__content",
        "c-banner__content--responsive",
        "c-banner__content--" <> CSSHelpers.atom_to_class(banner.banner_type),
        "c-banner__content--" <> CSSHelpers.atom_to_class(banner.text_position)
        | banner_bg_class(banner)
      ],
      " "
    )
  end

  @spec banner_bg_class(Banner.t()) :: [String.t()]
  defp banner_bg_class(%Banner{banner_type: :important}), do: []
  defp banner_bg_class(%Banner{routes: []}), do: ["u-bg--unknown"]
  defp banner_bg_class(%Banner{routes: [route | _]}), do: ["u-bg--" <> cms_route_to_class(route)]

  @spec banner_cta(Banner.t()) :: Phoenix.HTML.Safe.t()
  defp banner_cta(%Banner{banner_type: :important, link: %{title: title}}) do
    content_tag(:span, title, class: "c-banner__cta")
  end

  defp banner_cta(%Banner{}) do
    ""
  end
end
