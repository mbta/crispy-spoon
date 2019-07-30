defmodule SiteWeb.CMS.PageView do
  @moduledoc """
  Handles rendering of partial content from the CMS.
  """
  use SiteWeb, :view

  import SiteWeb.CMS.ParagraphView, only: [render_paragraph: 2]

  alias CMS.Page
  alias CMS.Page.Project
  alias CMS.Paragraph
  alias Plug.Conn

  @doc "Universal wrapper for CMS page content"
  @spec render_page(Page.t(), Conn.t()) :: Phoenix.HTML.safe()
  def render_page(page, conn) do
    sidebar_left = Map.has_key?(page, :sidebar_menu) && !is_nil(page.sidebar_menu)
    sidebar_right = has_right_rail?(page)
    sidebar_layout = sidebar_classes(sidebar_left, sidebar_right)

    render(
      "_page.html",
      page: page,
      sidebar_left: sidebar_left,
      sidebar_right: sidebar_right,
      sidebar_class: sidebar_layout,
      conn: conn
    )
  end

  @doc """
  Intelligently choose and render page template content based on type, except
  for certain types which either have no template or require special values.
  """
  def render_page_content(%Project{} = page, conn) do
    render(
      "_project.html",
      page: page,
      conn: conn
    )
  end

  def render_page_content(page, conn) do
    render(
      "_generic.html",
      page: page,
      conn: conn
    )
  end

  @doc "Sets CMS content wrapper classes based on presence of sidebar elements {left, right}"
  @spec sidebar_classes(boolean, boolean) :: String.t()
  def sidebar_classes(true, _), do: "c-cms--with-sidebar c-cms--sidebar-left"
  def sidebar_classes(false, true), do: "c-cms--with-sidebar c-cms--sidebar-right"
  def sidebar_classes(false, false), do: "c-cms--no-sidebar"

  @spec has_right_rail?(Page.t()) :: boolean
  def has_right_rail?(%{paragraphs: paragraphs}) do
    Enum.any?(paragraphs, &right_rail_check(&1))
  end

  # Checks if any paragraphs have been assigned to the right rail.
  # If the paragraph is a ContentList.t(), ensure it has teasers.
  defp right_rail_check(paragraph) do
    if Paragraph.right_rail?(paragraph) do
      if Map.has_key?(paragraph, :teasers) do
        if Enum.empty?(paragraph.teasers), do: false, else: true
      else
        true
      end
    else
      false
    end
  end
end
