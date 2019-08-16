defmodule SiteWeb.CMSHelpers do
  @moduledoc """
  Various helper functions that aid in rendering CMS content.
  """

  import SiteWeb.ViewHelpers, only: [route_to_class: 1]
  import CSSHelpers, only: [string_to_class: 1]
  import Phoenix.HTML.Link

  alias CMS.API
  alias Routes.Repo

  @doc """
  Converts CMS-flavored routes to classes, where the route may
  not strictly be an ID that matches an elixir route ID.

  Example: authors can tag something with an umbrella term like
  "commuter_rail" or "silver_line" to indicate the content item
  is related to all routes on that mode or line.
  """
  @spec cms_route_to_class(API.route_term()) :: String.t()
  def cms_route_to_class(%{id: "Green"}), do: "green-line"
  def cms_route_to_class(%{id: "silver_line"}), do: "silver-line"
  def cms_route_to_class(%{id: "mattapan"}), do: "red-line"
  def cms_route_to_class(%{group: "custom", mode: nil}), do: "unknown"
  def cms_route_to_class(%{group: "custom", mode: mode}), do: string_to_class(mode)
  def cms_route_to_class(%{group: "mode", id: mode}), do: string_to_class(mode)
  def cms_route_to_class(%{id: id}), do: id |> Repo.get() |> route_to_class()

  @doc """
  Map certain CMS content categories to index pages of that content.
  If no match is found, simply output the original string category.
  """
  @spec link_category(String.t()) :: String.t() | Phoenix.HTML.safe()
  def link_category("Projects" = cat), do: link(cat, to: "/projects", title: "View all #{cat}")
  def link_category(category), do: category
end
