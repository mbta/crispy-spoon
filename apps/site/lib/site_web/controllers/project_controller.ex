defmodule SiteWeb.ProjectController do
  use SiteWeb, :controller

  alias Content.{Project, ProjectUpdate, Repo, Teaser}
  alias Plug.Conn
  alias SiteWeb.ProjectView

  @breadcrumb_base "Transforming the T"

  def index(conn, _) do
    project_teasers_fn = fn ->
      [type: :project, items_per_page: 50]
      |> Repo.teasers()
      |> sort_by_date()
    end

    featured_project_teasers_fn = fn ->
      [type: :project, sticky: 1]
      |> Repo.teasers()
      |> sort_by_date()
    end

    conn
    |> async_assign_default(:project_teasers, project_teasers_fn, [])
    |> async_assign_default(:featured_project_teasers, featured_project_teasers_fn, [])
    |> assign(:breadcrumbs, [Breadcrumb.build(@breadcrumb_base)])
    |> await_assign_all_default(__MODULE__)
    |> render("index.html")
  end

  @spec sort_by_date([Teaser.t()]) :: [Teaser.t()]
  defp sort_by_date(teasers) do
    Enum.sort(teasers, fn %{date: d1}, %{date: d2} ->
      {d1.year, d1.month, d1.day} >= {d2.year, d2.month, d2.day}
    end)
  end

  def show(%Conn{} = conn, _) do
    conn.request_path
    |> Repo.get_page(conn.query_params)
    |> do_show(conn)
  end

  defp do_show(%Project{} = project, conn) do
    show_project(conn, project)
  end

  defp do_show({:error, {:redirect, status, opts}}, conn) do
    conn
    |> put_status(status)
    |> redirect(opts)
  end

  defp do_show(_404_or_mismatch, conn) do
    render_404(conn)
  end

  @spec show_project(Conn.t(), Project.t()) :: Conn.t()
  def show_project(conn, project) do
    [past_events, upcoming_events, updates, diversions] =
      Util.async_with_timeout(
        [
          get_events_async(project.id, :past),
          get_events_async(project.id, :upcoming),
          get_updates_async(project.id),
          get_diversions_async(project.id)
        ],
        [],
        __MODULE__
      )

    breadcrumbs = [
      Breadcrumb.build(@breadcrumb_base, project_path(conn, :index)),
      Breadcrumb.build(project.title)
    ]

    conn
    |> put_view(ProjectView)
    |> render("show.html", %{
      breadcrumbs: breadcrumbs,
      project: project,
      updates: updates,
      past_events: past_events,
      upcoming_events: upcoming_events,
      diversions: diversions
    })
  end

  def project_updates(conn, %{"project_alias" => project_alias}) do
    get_page_fn = Map.get(conn.assigns, :get_page_fn, &Repo.get_page/1)
    teasers_fn = Map.get(conn.assigns, :teasers_fn, &Repo.teasers/1)

    "/projects"
    |> Path.join(project_alias)
    |> get_page_fn.()
    |> case do
      %Project{} = project ->
        breadcrumbs = [
          Breadcrumb.build(@breadcrumb_base, project_path(conn, :index)),
          Breadcrumb.build(project.title, project_path(conn, :show, project)),
          Breadcrumb.build("Updates")
        ]

        conn
        |> put_view(ProjectView)
        |> render("updates.html", %{
          breadcrumbs: breadcrumbs,
          project: project,
          updates:
            teasers_fn.(
              related_to: project.id,
              type: :project_update,
              items_per_page: 50
            )
        })

      {:error, {:redirect, status, [to: "/projects/" <> redirect_alias]}} ->
        conn
        |> put_status(status)
        |> redirect(to: project_updates_path(conn, :project_updates, redirect_alias))

      {:error, :not_found} ->
        render_404(conn)

      _ ->
        conn
        |> put_status(:bad_gateway)
        |> put_view(SiteWeb.ErrorView)
        |> render("crash.html", [])
        |> halt()
    end
  end

  def project_update(%Conn{} = conn, _params) do
    conn.request_path
    |> Repo.get_page(conn.query_params)
    |> do_project_update(conn)
  end

  defp do_project_update(%ProjectUpdate{} = update, conn) do
    show_project_update(conn, update)
  end

  defp do_project_update({:error, {:redirect, status, opts}}, conn) do
    conn
    |> put_status(status)
    |> redirect(opts)
  end

  defp do_project_update(_404_or_mismatch, conn) do
    render_404(conn)
  end

  @spec show_project_update(Conn.t(), ProjectUpdate.t()) :: Conn.t()
  def show_project_update(%Conn{} = conn, %ProjectUpdate{} = update) do
    case Repo.get_page(update.project_url) do
      %Project{} = project ->
        breadcrumbs = [
          Breadcrumb.build(@breadcrumb_base, project_path(conn, :index, [])),
          Breadcrumb.build(project.title, project_path(conn, :show, project)),
          Breadcrumb.build(
            "Updates",
            project_updates_path(conn, :project_updates, Project.alias(project))
          ),
          Breadcrumb.build(update.title)
        ]

        conn
        |> put_view(ProjectView)
        |> render("update.html", %{
          breadcrumbs: breadcrumbs,
          update: update
        })

      {:error, {:redirect, _, [to: path]}} ->
        show_project_update(conn, %{update | project_url: path})

      _ ->
        render_404(conn)
    end
  end

  @spec get_events_async(integer, :past | :upcoming) :: (() -> [Teaser.t()])
  def get_events_async(id, :past) do
    fn ->
      Repo.teasers(
        type: :event,
        related_to: id,
        items_per_page: 10,
        date_op: "<",
        date: [value: "now"],
        sort_order: "DESC"
      )
    end
  end

  def get_events_async(id, :upcoming) do
    fn ->
      Repo.teasers(
        type: :event,
        related_to: id,
        items_per_page: 10,
        date_op: ">=",
        date: [value: "now"],
        sort_order: "ASC"
      )
    end
  end

  @spec get_updates_async(integer) :: (() -> [Teaser.t()])
  def get_updates_async(id) do
    fn -> Repo.teasers(related_to: id, type: :project_update) end
  end

  @spec get_diversions_async(integer) :: (() -> [Teaser.t()])
  def get_diversions_async(id) do
    fn -> Repo.teasers(related_to: id, type: :diversion) end
  end
end
