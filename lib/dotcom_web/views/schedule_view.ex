defmodule DotcomWeb.ScheduleView do
  @moduledoc false

  use DotcomWeb, :view

  require Routes.Route

  import DotcomWeb.ScheduleView.StopList
  import DotcomWeb.ScheduleView.Timetable

  alias CMS.Partial.RoutePdf
  alias Dotcom.MapHelpers
  alias DotcomWeb.PartialView.{HeaderTab, HeaderTabs, SvgIconWithCircle}
  alias Phoenix.HTML.Safe
  alias Plug.Conn
  alias Routes.Route
  alias Stops.Stop

  @subway_order [
    "Red",
    "Orange",
    "Green-B",
    "Green-C",
    "Green-D",
    "Green-E",
    "Blue",
    "Mattapan"
  ]

  defdelegate update_schedule_url(conn, opts), to: UrlHelpers, as: :update_url

  @spec template_for_tab(String.t()) :: String.t()
  @doc "Returns the template for the selected tab."
  def template_for_tab(tab_name)
  def template_for_tab("timetable"), do: "_timetable.html"
  def template_for_tab("line"), do: "_line.html"
  def template_for_tab("alerts"), do: "_alerts.html"

  @spec reverse_direction_opts(0 | 1) :: Keyword.t()
  def reverse_direction_opts(direction_id) do
    [
      trip: nil,
      schedule_direction: %{
        direction_id: direction_id
      }
    ]
  end

  @doc """
  The message to show when there are no trips for the given parameters.
  Expects either an error, two stops, or a direction.
  """
  @spec no_trips_message(
          JsonApi.Error.t() | nil,
          String.t() | nil,
          Date.t()
        ) :: iodata
  def no_trips_message(%{code: "no_service"} = error, _, date) do
    [
      content_tag(:div, [
        format_full_date(date),
        " is outside of our current schedule."
      ]),
      content_tag(:div, [
        "We can only provide trip data for the ",
        rating_name(error),
        " schedule, valid until ",
        rating_end_date(error),
        "."
      ])
    ]
  end

  def no_trips_message(_, direction, date) when not is_nil(direction) and not is_nil(date) do
    [
      "There are no scheduled ",
      downcase_direction(direction),
      " trips on ",
      format_full_date(date),
      "."
    ]
  end

  def no_trips_message(_, direction, nil) when not is_nil(direction) do
    [
      "There are no scheduled ",
      downcase_direction(direction),
      " trips."
    ]
  end

  def no_trips_message(
        _,
        _,
        date
      )
      when not is_nil(date) do
    [
      "There are no scheduled trips on ",
      format_full_date(date),
      "."
    ]
  end

  def no_trips_message(_, _, _), do: "There are no scheduled trips."

  defp rating_name(%{meta: %{"version" => version}}) do
    version
    |> String.split(" ", parts: 2)
    |> List.first()
  end

  defp rating_end_date(%{meta: %{"end_date" => end_date}}) do
    end_date
    |> Timex.parse!("{ISOdate}")
    |> Timex.format!("{Mfull} {D}, {YYYY}")
  end

  for direction <- ["Outbound", "Inbound", "West", "East", "North", "South"] do
    defp downcase_direction(unquote(direction)), do: unquote(String.downcase(direction))
  end

  defp downcase_direction(direction) do
    # keep it the same if it's not one of our expected ones
    direction
  end

  @spec route_pdfs([RoutePdf.t()] | nil, Route.t(), Date.t()) :: [map]
  def route_pdfs(route_pdfs, route, today) do
    route_pdfs = route_pdfs || []
    all_current? = Enum.all?(route_pdfs, &RoutePdf.started?(&1, today))
    Enum.map(route_pdfs, &route_pdfs_map(&1, route, today, all_current?))
  end

  @spec route_pdfs_map(RoutePdf.t(), Route.t(), Date.t(), boolean) :: map
  def route_pdfs_map(pdf, route, today, all_current?) do
    %{
      url: static_url(DotcomWeb.Endpoint, pdf.path),
      title: IO.iodata_to_binary(route_pdf_title(pdf, route, today, all_current?))
    }
  end

  @spec route_pdf_link([RoutePdf.t()] | nil, Route.t(), Date.t()) :: Safe.t()
  def route_pdf_link(route_pdfs, route, today) do
    route_pdfs = route_pdfs || []
    all_current? = Enum.all?(route_pdfs, &RoutePdf.started?(&1, today))

    content_tag :div, class: "pdf-links" do
      for pdf <- route_pdfs do
        url = static_url(DotcomWeb.Endpoint, pdf.path)

        content_tag :div, class: "schedules-pdf-link" do
          link(to: url, target: "_blank") do
            text_for_route_pdf(pdf, route, today, all_current?)
          end
        end
      end
    end
  end

  @spec route_pdf_title(RoutePdf.t(), Route.t(), Date.t(), boolean) :: iodata
  def route_pdf_title(pdf, route, today, all_current?) do
    current_or_upcoming_text =
      cond do
        all_current? -> ""
        RoutePdf.started?(pdf, today) -> "Current "
        true -> "Upcoming "
      end

    pdf_name =
      cond do
        RoutePdf.custom?(pdf) -> pdf.link_text_override
        Route.commuter_rail?(route) -> [pretty_route_name(route), " schedule"]
        true -> [pretty_route_name(route), " schedule and map"]
      end

    effective_date_text =
      if RoutePdf.started?(pdf, today) do
        ""
      else
        [" — effective ", pretty_date(pdf.date_start)]
      end

    [
      current_or_upcoming_text,
      pdf_name,
      " PDF",
      effective_date_text
    ]
  end

  @spec text_for_route_pdf(RoutePdf.t(), Route.t(), Date.t(), boolean) :: iodata
  defp text_for_route_pdf(pdf, route, today, all_current?) do
    [
      fa("file-pdf-o"),
      " ",
      route_pdf_title(pdf, route, today, all_current?)
    ]
  end

  @spec pretty_route_name(Route.t()) :: String.t()
  def pretty_route_name(route) do
    route_prefix = if route.type == 3, do: "Route ", else: ""

    route_name =
      route.name
      |> String.replace_trailing(" Line", " line")
      |> String.replace_trailing(" Ferry", " ferry")
      |> String.replace_trailing(" Trolley", " trolley")
      |> break_text_at_slash

    route_prefix <> route_name
  end

  @spec fare_params(Stop.t(), Stop.t()) :: %{
          optional(:origin) => Stop.id_t(),
          optional(:destination) => Stop.id_t()
        }
  def fare_params(origin, destination) do
    case {origin, destination} do
      {nil, nil} -> %{}
      {origin, nil} -> %{origin: origin}
      {origin, destination} -> %{origin: origin, destination: destination}
    end
  end

  @doc "Prefix route name with route for bus lines"
  @spec route_header_text(Route.t()) :: [String.t()] | Safe.t()
  def route_header_text(%Route{type: 3, name: name} = route) do
    if Route.silver_line?(route) do
      if route.id == "746" do
        "Silver Line Waterfront"
      else
        ["Silver Line ", name]
      end
    else
      content_tag :div, class: "bus-route-sign" do
        route.name
      end
    end
  end

  def route_header_text(%Route{type: 2, name: name}), do: [clean_route_name(name)]
  def route_header_text(%Route{name: name}), do: [name]

  @spec header_class(Route.t()) :: String.t()
  def header_class(%Route{type: 3} = route) do
    if Route.silver_line?(route) do
      do_header_class("silver-line")
    else
      do_header_class("bus")
    end
  end

  def header_class(%Route{} = route) do
    route
    |> route_to_class()
    |> do_header_class()
  end

  @spec do_header_class(String.t()) :: String.t()
  defp do_header_class(<<modifier::binary>>) do
    "u-bg--" <> modifier
  end

  @doc "Route sub text (long names for bus routes)"
  @spec route_header_description(Route.t()) :: String.t()
  def route_header_description(%Route{type: 3} = route) do
    if Route.silver_line?(route) do
      ""
    else
      content_tag :h2, class: "schedule__description notranslate" do
        if route.long_name == "" do
          "Bus Route"
        else
          route.long_name
        end
      end
    end
  end

  def route_header_description(_), do: ""

  def route_header_tabs(conn) do
    route = conn.assigns.route
    tab_params = conn.assigns.tab_params
    info_link = line_path(conn, :show, route.id, tab_params)
    timetable_link = timetable_path(conn, :show, route.id, tab_params)
    alerts_link = alerts_path(conn, :show, route.id, tab_params)

    tabs = [
      %HeaderTab{
        id: "alerts",
        name: "Alerts",
        href: alerts_link,
        badge: conn |> alert_count() |> alert_badge()
      }
    ]

    tabs =
      case route.type do
        n when n in [2, 4] ->
          [
            %HeaderTab{id: "timetable", name: "Timetable", href: timetable_link},
            %HeaderTab{id: "line", name: "Schedule & Maps", href: info_link} | tabs
          ]

        _ ->
          [
            %HeaderTab{id: "line", name: "Schedules & Maps", href: info_link} | tabs
          ]
      end

    HeaderTabs.render_tabs(tabs, selected: conn.assigns.tab, tab_class: route_tab_class(route))
  end

  @spec alert_count(Conn.t()) :: integer
  defp alert_count(%{assigns: %{all_alerts_count: all_alerts_count}}), do: all_alerts_count
  defp alert_count(_), do: 0

  @spec route_tab_class(Route.t()) :: String.t()
  defp route_tab_class(%Route{type: 3} = route) do
    if Route.silver_line?(route) do
      ""
    else
      "header-tab--bus"
    end
  end

  defp route_tab_class(_), do: ""

  @spec route_fare_link(Route.t()) :: String.t()
  def route_fare_link(route) do
    route_type =
      route
      |> Route.type_atom()
      |> Atom.to_string()
      |> String.replace("_", "-")

    "/fares/" <> route_type <> "-fares"
  end

  @spec single_trip_fares(Route.t()) :: [{String.t(), String.t() | iolist}]
  @doc """
  Returns a list of fares for a single trip. If the route is a free fare route, we override the fares with "Free".
  """
  def single_trip_fares(%Route{fare_class: :free_fare} = route) do
    route
    |> to_fare_summary_atom()
    |> mode_summaries()
    |> Enum.find(fn summary -> summary.duration == :single_trip end)
    |> (&(&1.fares || [])).()
    |> Enum.map(fn fare ->
      {elem(fare, 0), "Free"}
    end)
  end

  def single_trip_fares(route) do
    route
    |> to_fare_summary_atom()
    |> mode_summaries()
    |> Enum.find(fn summary -> summary.duration == :single_trip end)
    |> (&(&1.fares || [])).()
  end

  @spec to_fare_summary_atom(Route.t()) :: atom
  def to_fare_summary_atom(%Route{type: 3, id: id}) do
    cond do
      Fares.silver_line_rapid_transit?(id) -> :subway
      Fares.express?(id) -> :express_bus
      true -> :bus
    end
  end

  def to_fare_summary_atom(route), do: Route.type_atom(route)

  @spec sort_connections([Route.t()]) :: [Route.t()]
  def sort_connections(routes) do
    {cr, subway} =
      routes
      |> Enum.reject(&(&1.type === 3 or &1.type === 4))
      |> Enum.split_with(&(&1.type == 2))

    Enum.sort(subway, &sort_subway/2) ++ Enum.sort(cr, &(&1.name < &2.name))
  end

  defp sort_subway(route_a, route_b) do
    Enum.find_index(@subway_order, fn x -> x == route_a.id end) <
      Enum.find_index(@subway_order, fn x -> x == route_b.id end)
  end

  @spec timetable_note(Conn.t() | map) :: Safe.t() | nil
  def timetable_note(%{route: %Route{id: "CR-Foxboro"}, direction_id: _}) do
    content_tag :div, class: "m-timetable__note" do
      [
        content_tag(:p, [
          content_tag(:strong, "Note:"),
          " Trains depart from Foxboro 30 minutes after conclusion of events"
        ])
      ]
    end
  end

  def timetable_note(_), do: nil

  def json_safe_route(route) do
    Route.to_json_safe(route)
  end

  @spec station?(Stops.Stop.t()) :: boolean()
  def station?(stop) do
    stop.station?
  end
end
