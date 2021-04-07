defmodule SiteWeb.CmsRouterHelpers do
  @moduledoc """
  A replacement module for path helpers from RouterHelpers.
  This allows us to use either a path_alias if it exists
  to fetch from the CMS. If no path_alias exists, we will
  fetch using "/type/:id" In the case where we are using the
  id, we delegate to the Phoenix helpers from RouterHelpers.
  """
  alias Plug.Conn
  alias SiteWeb.Router.Helpers, as: RouterHelpers
  alias SiteWeb.ViewHelpers

  alias CMS.Page.{
    Event,
    NewsEntry,
    Project,
    ProjectUpdate
  }

  alias CMS.Partial.Teaser

  @spec news_entry_path(
          Conn.t() | nil,
          atom,
          Keyword.t() | NewsEntry.t() | Teaser.t() | String.t()
        ) :: String.t()
  def news_entry_path(conn, verb, opts \\ [])

  def news_entry_path(conn, :index, opts) do
    RouterHelpers.news_entry_path(conn, :index, opts)
  end

  def news_entry_path(conn, :show, %Teaser{} = news_entry) do
    check_preview(conn, news_entry.path)
  end

  def news_entry_path(conn, :show, %NewsEntry{path_alias: nil} = news_entry) do
    check_preview(conn, "/node/#{news_entry.id}")
  end

  def news_entry_path(conn, :show, %NewsEntry{} = news_entry) do
    check_preview(conn, news_entry.path_alias)
  end

  def news_entry_path(conn, :show, value) when is_binary(value) do
    check_preview(conn, RouterHelpers.news_entry_path(conn, :show, [value]))
  end

  @spec news_entry_path(Conn.t(), atom, String.t(), String.t()) :: String.t()
  def news_entry_path(conn, :show, date, title) when is_binary(date) and is_binary(title) do
    check_preview(conn, RouterHelpers.news_entry_path(conn, :show, [date, title]))
  end

  @spec event_path(Conn.t(), atom, Keyword.t() | Event.t() | String.t()) :: String.t()
  def event_path(conn, verb, opts \\ [])

  def event_path(conn, :index, opts) do
    RouterHelpers.event_path(conn, :index, opts)
  end

  def event_path(conn, :show, %Event{path_alias: nil} = event) do
    check_preview(conn, "/node/#{event.id}")
  end

  def event_path(conn, :show, %Event{} = event) do
    check_preview(conn, event.path_alias)
  end

  def event_path(conn, :show, value) when is_binary(value) do
    check_preview(conn, RouterHelpers.event_path(conn, :show, [value]))
  end

  @spec event_path(Conn.t(), atom, String.t(), String.t()) :: String.t()
  def event_path(conn, :show, date, title) when is_binary(date) and is_binary(title) do
    check_preview(conn, RouterHelpers.event_path(conn, :show, [date, title]))
  end

  def event_icalendar_path(conn, :show, %Event{} = event) do
    ["", route | path] =
      conn
      |> event_path(:show, event)
      |> String.split("/")

    check_preview(conn, Path.join(["/", route, "icalendar" | path]))
  end

  def event_icalendar_path(conn, path) when is_binary(path) do
    ["", route | path] = String.split(path, "/")
    check_preview(conn, Path.join(["/", route, "icalendar" | path]))
  end

  @spec project_path(
          Conn.t() | module,
          atom,
          Keyword.t() | Project.t() | Teaser.t() | String.t()
        ) :: String.t()
  def project_path(conn, verb, opts \\ [])

  def project_path(conn, :index, opts) do
    RouterHelpers.project_path(conn, :index, opts)
  end

  def project_path(conn, :show, %Teaser{} = project) do
    check_preview(conn, project.path)
  end

  def project_path(conn, :show, %Project{path_alias: nil} = project) do
    check_preview(conn, "/node/#{project.id}")
  end

  def project_path(conn, :show, %Project{} = project) do
    check_preview(conn, project.path_alias)
  end

  def project_path(conn, :show, value) when is_binary(value) do
    check_preview(conn, "/projects/#{value}")
  end

  @spec project_update_path(Conn.t(), atom, ProjectUpdate.t() | Teaser.t()) :: String.t()
  def project_update_path(
        conn,
        :project_update,
        %ProjectUpdate{path_alias: nil} = project_update
      ) do
    check_preview(conn, "/node/#{project_update.id}")
  end

  def project_update_path(conn, :project_update, %ProjectUpdate{} = project_update) do
    check_preview(conn, project_update.path_alias)
  end

  def project_update_path(conn, :project_update, %Teaser{} = project_update) do
    check_preview(conn, project_update.path)
  end

  @spec project_update_path(module | Conn.t(), atom, String.t(), String.t()) :: String.t()
  def project_update_path(conn, :project_update, project, update) do
    check_preview(conn, "/projects/#{project}/update/#{update}")
  end

  @spec check_preview(module | Conn.t(), String.t()) :: String.t()
  defp check_preview(conn, path), do: ViewHelpers.cms_static_page_path(conn, path)
end
