defmodule DotcomWeb.ScheduleController.CMS do
  @moduledoc """
  Fetches teaser content from the CMS.
  """

  import Util.AsyncAssign, only: [async_assign_default: 4]

  alias Routes.Route
  alias CMS.{Partial.Teaser, Repo}

  @behaviour Plug

  @featured_opts [
    type: [:project, :project_update, :page],
    items_per_page: 1,
    sidebar: 1
  ]

  @impl Plug
  def init([]), do: []

  @impl Plug
  def call(conn, _) do
    Util.log_duration(__MODULE__, :do_call, [conn])
  end

  def do_call(%{assigns: %{route: route}} = conn) do
    featured_fn = fn ->
      @featured_opts
      |> Keyword.put(:route_id, route.id)
      |> Repo.teasers()
      |> Enum.take(1)
      |> Enum.map(&set_utm_params(&1, route))
    end

    news_fn = fn ->
      teasers =
        [route_id: route.id, type: [:news_entry], sidebar: 1]
        |> Repo.teasers()
        |> Enum.map(&set_utm_params(&1, route))

      mode_from_route_desc = get_mode_from_route_description(route.description)

      mode_teasers =
        if mode_from_route_desc == nil do
          []
        else
          [mode: mode_from_route_desc, type: [:news_entry], sidebar: 1]
          |> Repo.teasers()
          |> Enum.map(&set_utm_params(&1, route))
        end

      (teasers ++ mode_teasers)
      |> Enum.uniq_by(fn teaser -> teaser.title end)
      |> Enum.sort_by(& &1.date, &(Timex.compare(&1, &2) == 1))
      |> Enum.slice(0, 5)
    end

    conn
    |> async_assign_default(:featured_content, featured_fn, nil)
    |> async_assign_default(:news, news_fn, [])
  end

  defp set_utm_params(nil, %Route{}) do
    nil
  end

  defp set_utm_params(%Teaser{} = teaser, %Route{} = route) do
    url =
      UrlHelpers.build_utm_url(
        teaser,
        source: "schedule",
        type: utm_type(teaser.type),
        term: Route.type_atom(route)
      )

    %{teaser | path: url}
  end

  defp utm_type(:news_entry), do: :news
  defp utm_type(type), do: type

  @spec get_mode_from_route_description(Route.gtfs_route_desc()) :: String.t() | nil
  defp get_mode_from_route_description(description) do
    case description do
      :commuter_rail ->
        "commuter-rail"

      :rapid_transit ->
        "subway"

      bus
      when bus in [
             :key_bus_route,
             :local_bus,
             :commuter_bus,
             :supplemental_bus,
             :rail_replacement_bus,
             :community_bus
           ] ->
        "bus"

      :ferry ->
        "ferry"

      _ ->
        nil
    end
  end
end
