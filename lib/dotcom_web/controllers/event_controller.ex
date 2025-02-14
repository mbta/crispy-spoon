defmodule DotcomWeb.EventController do
  @moduledoc "Handles fetching event data for event views"

  use DotcomWeb, :controller

  alias CMS.{API, Page, Repo}
  alias CMS.Page.Event
  alias Dotcom.IcalendarGenerator
  alias DotcomWeb.ControllerHelpers
  alias DotcomWeb.EventView
  alias Plug.Conn

  plug(DotcomWeb.Plugs.YearMonth)
  plug(:assign_events)

  def index(conn, %{"calendar" => "true"}) do
    render_events_hub_page(conn, true)
  end

  def index(conn, _params) do
    render_events_hub_page(conn, false)
  end

  defp render_events_hub_page(conn, is_calendar_view_mode) do
    conn
    |> assign(:calendar_view, is_calendar_view_mode)
    |> assign(:breadcrumbs, [Breadcrumb.build("Events")])
    |> await_assign_all_default(__MODULE__)
    |> render("index.html", conn: conn)
  end

  defp assign_events(conn, _opts) do
    events_by_year =
      for year <- year_options(conn), into: %{} do
        {year, Repo.events_for_year(year)}
      end

    years_for_selection =
      events_by_year
      |> Enum.filter(fn {_year, events_for_that_year} -> Enum.count(events_for_that_year) > 0 end)
      |> Enum.map(fn {year, _events_for_that_year} -> year end)

    conn
    |> assign(:years_for_selection, years_for_selection)
    |> async_assign_default(
      :events,
      fn ->
        Map.get(events_by_year, conn.assigns.year, [])
      end,
      []
    )
  end

  def show(conn, %{"path_params" => path}) do
    case List.last(path) do
      "icalendar" ->
        redirect(conn, to: Path.join(["/events", "icalendar" | Enum.slice(path, 0..-2//1)]))

      _ ->
        conn.request_path
        |> Repo.get_page(conn.query_params)
        |> do_show(conn)
    end
  end

  defp do_show(%Event{} = event, conn) do
    show_event(conn, event)
  end

  defp do_show({:error, {:redirect, status, opts}}, conn) do
    conn
    |> put_status(status)
    |> redirect(opts)
  end

  defp do_show(_404_or_mismatch, conn) do
    render_404(conn)
  end

  @spec show_event(Conn.t(), Event.t()) :: Conn.t()
  def show_event(conn, %Event{start_time: start_time} = event) do
    conn
    |> ControllerHelpers.unavailable_after_one_year(start_time)
    |> assign_breadcrumbs(event)
    |> put_view(EventView)
    |> render("show.html", event: event)
  end

  @spec assign_breadcrumbs(Conn.t(), Event.t()) :: Conn.t()
  defp assign_breadcrumbs(conn, event) do
    conn
    |> assign(:breadcrumbs, [
      Breadcrumb.build("Events", event_path(conn, :index)),
      Breadcrumb.build(event.title)
    ])
  end

  @spec icalendar(Conn.t(), map) :: Conn.t()
  def icalendar(%{request_path: path} = conn, _) do
    path
    |> String.replace("/icalendar", "")
    |> Repo.get_page(conn.query_params)
    |> do_icalendar(conn)
  end

  @spec do_icalendar(Page.t() | {:error, API.error()}, Conn.t()) :: Conn.t()
  defp do_icalendar(%Event{} = event, conn) do
    conn
    |> put_resp_content_type("text/calendar")
    |> put_resp_header("content-disposition", "attachment; filename=#{filename(event.title)}.ics")
    |> send_resp(200, IcalendarGenerator.to_ical(conn, event))
  end

  defp do_icalendar({:error, {:redirect, _status, [to: path]}}, conn) do
    path
    |> Repo.get_page(conn.query_params)
    |> do_icalendar(conn)
  end

  defp do_icalendar(_, conn) do
    render_404(conn)
  end

  @spec filename(String.t()) :: String.t()
  defp filename(title) do
    title
    |> String.downcase()
    |> String.replace(" ", "_")
    |> URI.encode_www_form()
    |> decode_ampersand_html_entity()
  end

  @spec decode_ampersand_html_entity(String.t()) :: String.t()
  defp decode_ampersand_html_entity(string) do
    String.replace(string, "%26", "&")
  end

  @doc "Returns a list of years with which we can filter events.
  Defaults to the current datetime if no assigns
  "
  @spec year_options(Plug.Conn.t()) :: Range.t(first: Calendar.year(), last: Calendar.year())
  def year_options(%{assigns: %{date: %{year: year}}}) when is_integer(year) do
    do_year_options(year)
  end

  def year_options(_) do
    %{year: year} = Util.now()
    do_year_options(year)
  end

  @spec do_year_options(Calendar.year()) :: Range.t(first: Calendar.year(), last: Calendar.year())
  defp do_year_options(year), do: Range.new(year - 4, year + 1)
end
