defmodule DotcomWeb.PageController do
  @moduledoc false
  use DotcomWeb, :controller

  import DotcomWeb.CMSHelpers, only: [cms_route_to_class: 1]

  alias CMS.Repo

  alias CMS.Partial.{
    Banner,
    Paragraph,
    Teaser,
    WhatsHappeningItem
  }

  plug(:alerts)
  plug(DotcomWeb.Plugs.RecentlyVisited)
  plug(:subway_status)

  @type content :: Banner.t() | Teaser.t() | WhatsHappeningItem.t()
  @type whats_happening_set :: {nil | [WhatsHappeningItem.t()], nil | [WhatsHappeningItem.t()]}

  def index(conn, _params) do
    {promoted, remainder} = whats_happening_items()
    banner = banner()
    fares = fares(conn.query_params)

    conn
    |> assign(
      :meta_description,
      "Public transit in the Greater Boston region. Routes, schedules, trip planner, fares, " <>
        "service alerts, real-time updates, and general information."
    )
    |> async_assign_default(:news, &news/0, [])
    |> async_assign_default(:banner, fn -> banner end)
    |> async_assign_default(:homepage_fares, fn -> fares end)
    |> async_assign_default(:promoted_items, fn -> promoted end)
    |> async_assign_default(:whats_happening_items, fn -> remainder end)
    |> async_assign_default(:alerts, fn -> Alerts.Repo.all(conn.assigns.date_time) end)
    |> async_assign_default(
      :event_teasers,
      fn -> CMS.Repo.next_n_event_teasers(conn.assigns.date, 6) end,
      []
    )
    |> await_assign_all_default(__MODULE__)
    |> render("index.html")
  end

  def menu(conn, _params) do
    conn
    |> render("menu.html")
  end

  @spec fares(map) :: Paragraph.t() | nil
  defp fares(query_params) do
    case Repo.get_paragraph("paragraphs/multi-column/homepage-fares", query_params) do
      {:error, _} -> nil
      result -> result
    end
  end

  @spec banner :: Banner.t() | nil
  defp banner do
    case Repo.banner() do
      nil -> nil
      banner -> add_utm_url(banner)
    end
  end

  @spec news :: [Teaser.t()]
  defp news do
    [items_per_page: 6, type: [:news_entry]]
    |> Repo.teasers()
    |> Enum.map(&add_utm_url/1)
  end

  @spec whats_happening_items :: whats_happening_set
  defp whats_happening_items do
    Repo.whats_happening()
    |> split_whats_happening()
    |> split_add_utm_url()
  end

  @spec split_whats_happening([WhatsHappeningItem.t()]) :: whats_happening_set
  def split_whats_happening(whats_happening) do
    case whats_happening do
      [_, _, _, _, _ | _] = items ->
        {first_two, rest} = Enum.split(items, 2)
        {first_two, Enum.take(rest, 3)}

      [_, _ | _] = items ->
        {Enum.take(items, 2), []}

      _ ->
        {nil, nil}
    end
  end

  @spec split_add_utm_url(whats_happening_set) :: whats_happening_set
  defp split_add_utm_url({nil, nil}) do
    {nil, nil}
  end

  defp split_add_utm_url({promoted, rest}) do
    {
      Enum.map(promoted, &add_utm_url(&1, true)),
      Enum.map(rest, &add_utm_url/1)
    }
  end

  @spec add_utm_url(content, boolean) :: content
  def add_utm_url(%{} = item, promoted? \\ false) do
    url =
      UrlHelpers.build_utm_url(
        item,
        type: utm_type(item, promoted?),
        term: utm_term(item),
        source: "homepage"
      )

    do_add_utm_url(item, url)
  end

  @spec utm_type(content, boolean) :: String.t()
  defp utm_type(%Banner{}, _), do: "banner"
  defp utm_type(%Teaser{type: :news_entry}, _), do: "news"
  defp utm_type(%WhatsHappeningItem{}, true), do: "whats-happening"
  defp utm_type(%WhatsHappeningItem{}, false), do: "whats-happening-secondary"

  @spec utm_term(content) :: String.t()
  defp utm_term(%{routes: [route | _]}), do: cms_route_to_class(route)
  defp utm_term(_), do: "null"

  @spec do_add_utm_url(content, String.t()) :: content
  defp do_add_utm_url(%Teaser{} = item, url), do: %{item | path: url}
  defp do_add_utm_url(item, url), do: %{item | utm_url: url}

  defp alerts(conn, _opts) do
    alerts = Alerts.Repo.all(conn.assigns.date_time)

    assign(conn, :alerts, alerts)
  end

  defp subway_status(conn, _opts) do
    assign(conn, :subway_status, Dotcom.SystemStatus.subway_status())
  end
end
