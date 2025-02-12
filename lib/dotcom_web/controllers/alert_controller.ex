defmodule DotcomWeb.AlertController do
  use DotcomWeb, :controller
  alias Alerts.{Alert, InformedEntity, Match, Repo}
  alias Stops.Stop

  plug(:route_type)
  plug(:routes)
  plug(:alerts)
  plug(DotcomWeb.Plugs.AlertsByTimeframe)
  plug(DotcomWeb.Plug.Mticket)
  plug(:subway_status)

  @routes_repo Application.compile_env!(:dotcom, :repo_modules)[:routes]
  @stops_repo Application.compile_env!(:dotcom, :repo_modules)[:stops]

  @valid_ids ~w(subway commuter-rail bus ferry access)s

  def index(conn, _params) do
    conn
    |> redirect(to: alert_path(conn, :show, "subway"))
    |> halt
  end

  def show(%{assigns: %{alerts: alerts}} = conn, %{"id" => "access"}) do
    conn
    |> render_alert_groups(group_access_alerts(alerts))
  end

  def show(conn, %{"id" => mode}) when mode in @valid_ids do
    if mode == "subway" do
      conn
      |> assign(
        :alerts,
        Enum.reject(conn.assigns.alerts, &Dotcom.Alerts.service_impacting_alert?/1)
      )
      |> render_routes()
    else
      render_routes(conn)
    end
  end

  def show(conn, _params) do
    check_cms_or_404(conn)
  end

  @spec show_by_stop(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_by_stop(conn, %{"stop_id" => stop_id}) do
    alerts = Repo.by_stop_id(stop_id)
    json(conn, alerts)
  end

  @spec show_by_routes(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_by_routes(%{query_params: %{"route_ids" => route_ids}} = conn, _) do
    route_id_array = String.split(route_ids, ",")
    alerts = Repo.by_route_ids(route_id_array, DateTime.utc_now())
    json(conn, alerts)
  end

  def show_by_routes(conn, _) do
    json(conn, [])
  end

  def render_routes(%{assigns: %{alerts: alerts, routes: routes}} = conn) do
    render_alert_groups(conn, Enum.map(routes, &route_alerts(&1, excluding_banner(conn, alerts))))
  end

  def render_alert_groups(%{params: %{"id" => id}} = conn, route_alerts) do
    conn
    |> assign(
      :meta_description,
      "Live service alerts for all MBTA transportation modes, including subway, bus, Commuter Rail, and ferry. " <>
        "Updates on delays, construction, elevator outages, and more."
    )
    |> render(
      "show.html",
      id: id_to_atom(id),
      alert_groups: route_alerts |> Enum.reject(&match?({_, []}, &1)),
      breadcrumbs: [Breadcrumb.build("Alerts")]
    )
  end

  def route_alerts(%Routes.Route{} = route, alerts) do
    entity = %InformedEntity{
      route_type: route.type,
      route: route.id
    }

    {route, Match.match(alerts, entity)}
  end

  def group_access_alerts(alerts) do
    access_effects = Alert.access_alert_types() |> Keyword.keys() |> MapSet.new()

    alerts
    |> Enum.filter(&MapSet.member?(access_effects, &1.effect))
    |> Enum.reduce(%{}, &group_access_alerts_by_stop/2)
    |> Enum.map(fn {stop_id, alerts} ->
      stop = @stops_repo.get_parent(stop_id)
      {stop, alerts}
    end)
    |> Enum.sort_by(fn {stop, _} -> stop.name end)
  end

  defp group_access_alerts_by_stop(%Alert{} = alert, acc) do
    alert.informed_entity.stop
    |> MapSet.to_list()
    |> Enum.reduce(acc, &do_group_access_alerts_by_stop(&1, alert, &2))
  end

  defp do_group_access_alerts_by_stop(stop_id, alert, acc) do
    # stop_ids are sometimes child stops.
    # Fetch the stop_id from the repo to get the parent id.
    case @stops_repo.get_parent(stop_id) do
      %Stop{id: parent_stop_id} ->
        Map.update(acc, parent_stop_id, MapSet.new([alert]), &MapSet.put(&1, alert))

      _ ->
        acc
    end
  end

  @spec excluding_banner(map, [Alert.t()]) :: [Alert.t()]
  def excluding_banner(%{assigns: %{alert_banner: alert_banner}}, alerts),
    do: Enum.reject(alerts, &(&1.id == alert_banner.id))

  def excluding_banner(_, alerts), do: alerts

  defp route_type(%{params: %{"id" => "subway"}} = conn, _opts), do: do_route_type(conn, [0, 1])
  defp route_type(%{params: %{"id" => "commuter-rail"}} = conn, _opts), do: do_route_type(conn, 2)
  defp route_type(%{params: %{"id" => "bus"}} = conn, _opts), do: do_route_type(conn, 3)
  defp route_type(%{params: %{"id" => "ferry"}} = conn, _opts), do: do_route_type(conn, 4)
  defp route_type(conn, _opts), do: conn

  defp do_route_type(conn, route_type) do
    assign(conn, :route_type, route_type)
  end

  defp routes(%{assigns: %{route_type: route_type}} = conn, _opts),
    do: assign(conn, :routes, @routes_repo.by_type(route_type))

  defp routes(conn, _opts), do: conn

  defp alerts(%{params: %{"id" => id}} = conn, _opts) when id in @valid_ids do
    alerts = Alerts.Repo.all(conn.assigns.date_time)
    assign(conn, :alerts, alerts)
  end

  defp alerts(conn, _opts) do
    conn
  end

  defp id_to_atom("commuter-rail"), do: :commuter_rail
  defp id_to_atom(id), do: String.to_existing_atom(id)

  defp subway_status(conn, _opts) do
    assign(conn, :subway_status, Dotcom.SystemStatus.subway_status())
  end
end
