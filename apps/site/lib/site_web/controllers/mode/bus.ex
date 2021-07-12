defmodule SiteWeb.Mode.BusController do
  use SiteWeb.Mode.HubBehavior,
    meta_description:
      "Schedule information for MBTA bus routes in the Greater Boston region, " <>
        "including real-time updates and arrival predictions."

  import Phoenix.HTML.Tag, only: [content_tag: 3]
  import Phoenix.HTML, only: [safe_to_string: 1]

  def route_type, do: 3

  def mode_name, do: "Bus"

  def mode_icon, do: :bus

  def fare_description do
    "For Express Bus fares, read the complete #{link_to_bus_fares()} page."
  end

  def fares do
    SiteWeb.ViewHelpers.mode_summaries(:bus)
  end

  defp link_to_bus_fares do
    path = fare_path(SiteWeb.Endpoint, :show, "bus-subway")
    tag = content_tag(:a, "Bus Fares", href: path)

    safe_to_string(tag)
  end
end
