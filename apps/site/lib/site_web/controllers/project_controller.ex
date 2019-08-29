defmodule SiteWeb.ProjectController do
  @moduledoc """
  Controller for project-related CMS content
  """
  use SiteWeb, :controller

  alias CMS.{Partial.Teaser, Repo}
  alias CMS.Page.{Project, ProjectUpdate}
  alias Plug.Conn
  alias SiteWeb.ProjectView

  @breadcrumb_base "Projects"
  @placeholder_image_path "/images/project-image-placeholder.png"
  @n_projects_per_page 10
  @n_project_updates_per_page 4

  def index(conn, _) do
    project_teasers_fn = fn ->
      fetch_teasers(0)
    end

    featured_project_teasers_fn = fn ->
      fetch_featured_teasers()
    end

    project_update_teasers_fn = fn ->
      fetch_update_teasers(0)
    end

    conn
    |> async_assign_default(:project_teasers, project_teasers_fn, [])
    |> async_assign_default(:featured_project_teasers, featured_project_teasers_fn, [])
    |> async_assign_default(:project_update_teasers, project_update_teasers_fn, [])
    |> assign(:breadcrumbs, [Breadcrumb.build(@breadcrumb_base)])
    |> assign(:placeholder_image_url, static_url(SiteWeb.Endpoint, @placeholder_image_path))
    |> await_assign_all_default(__MODULE__)
    |> render("index.html")
  end

  @spec sort_by_date([Teaser.t()]) :: [Teaser.t()]
  defp sort_by_date(teasers) do
    Enum.sort(teasers, fn %{date: d1}, %{date: d2} ->
      {d1.year, d1.month, d1.day} >= {d2.year, d2.month, d2.day}
    end)
  end

  def api(conn, %{"offset" => offset, "filter" => %{"mode" => mode}}) do
    mode = translate_mode(mode)
    offset = String.to_integer(offset)
    teasers = fetch_teasers(offset, mode)
    json(conn, teasers)
  end

  def api(conn, %{"filter" => %{"mode" => mode}}) do
    mode = translate_mode(mode)

    project_teasers_fn = fn ->
      fetch_teasers(0, mode)
    end

    featured_project_teasers_fn = fn ->
      fetch_featured_teasers(mode)
    end

    project_update_teasers_fn = fn ->
      fetch_update_teasers(0, mode)
    end

    project_teasers_task = Task.async(project_teasers_fn)
    featured_project_teasers_task = Task.async(featured_project_teasers_fn)
    project_update_teasers_task = Task.async(project_update_teasers_fn)
    project_teasers = Task.await(project_teasers_task)
    featured_project_teasers = Task.await(featured_project_teasers_task)
    project_update_teasers = Task.await(project_update_teasers_task)

    json(conn, %{
      "projects" => project_teasers,
      "featuredProjects" => featured_project_teasers,
      "projectUpdates" => project_update_teasers
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
              type: [:project_update],
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

  @spec simplify_teaser(map()) :: map()
  defp simplify_teaser(teaser) do
    teaser
    |> Map.put(:path, project_path(SiteWeb.Endpoint, :show, teaser))
    |> Map.take(~w(id text image path title routes date status)a)
  end

  @spec fetch_featured_teasers(String.t() | nil) :: [map()]
  defp fetch_featured_teasers(mode \\ nil) do
    api_params = [type: [:project], sticky: 1]

    api_params =
      if mode do
        Keyword.merge(api_params, mode: translate_mode(mode))
      else
        api_params
      end

    api_params
    |> Repo.teasers()
    |> sort_by_date()
    |> Enum.map(&simplify_teaser/1)
  end

  @spec fetch_teasers(integer, String.t() | nil) :: [map()]
  defp fetch_teasers(offset, mode \\ nil) do
    api_params = [type: [:project], items_per_page: @n_projects_per_page, offset: offset]

    api_params =
      if mode do
        Keyword.merge(api_params, mode: translate_mode(mode))
      else
        api_params
      end

    Repo.teasers(api_params)
    |> sort_by_date()
    |> Enum.map(&simplify_teaser/1)
  end

  @spec fetch_update_teasers(integer, String.t() | nil) :: [map()]
  defp fetch_update_teasers(offset, mode \\ nil) do
    mode = translate_mode(mode)

    api_params = [
      type: [:project_update],
      items_per_page: @n_project_updates_per_page,
      offset: offset
    ]

    api_params =
      if mode do
        Keyword.merge(api_params, mode: translate_mode(mode))
      else
        api_params
      end

    Repo.teasers(api_params)
    |> sort_by_date()
    |> Enum.map(&simplify_teaser/1)
  end

  @spec get_breadcrumb_base :: String.t()
  def get_breadcrumb_base do
    @breadcrumb_base
  end

  @spec translate_mode(String.t() | nil) :: String.t() | nil
  def translate_mode(mode) do
    case mode do
      "undefined" -> nil
      "commuter_rail" -> "commuter-rail"
      _ -> mode
    end
  end
end
