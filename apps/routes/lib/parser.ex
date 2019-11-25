defmodule Routes.Parser do
  alias JsonApi.Item
  alias RoutePatterns.RoutePattern
  alias Routes.{Route, Shape}

  @spec parse_route(Item.t()) :: Route.t()
  def parse_route(%Item{id: id, attributes: attributes}) do
    %Route{
      id: id,
      type: attributes["type"],
      name: name(attributes),
      long_name: attributes["long_name"],
      color: attributes["color"],
      direction_names: direction_bound_attrs(attributes["direction_names"]),
      direction_destinations: direction_attrs(attributes["direction_destinations"]),
      description: parse_gtfs_desc(attributes["description"])
    }
  end

  def parse_route_with_route_pattern(%Item{relationships: relationships} = item) do
    {parse_route(item), parse_route_patterns(relationships)}
  end

  defp parse_route_patterns(%{"route_patterns" => route_patterns}) do
    Enum.map(route_patterns, &RoutePattern.new(&1))
  end

  defp parse_route_patterns(_), do: []

  @spec name(map) :: String.t()
  defp name(%{"type" => 3, "short_name" => short_name}) when short_name != "", do: short_name
  defp name(%{"short_name" => short_name, "long_name" => ""}), do: short_name
  defp name(%{"long_name" => long_name}), do: long_name

  @spec direction_attrs([String.t()]) :: %{0 => String.t(), 1 => String.t()}
  defp direction_attrs([zero, one]) do
    %{0 => zero, 1 => one}
  end

  @spec direction_bound_attrs([String.t()]) :: %{0 => String.t(), 1 => String.t()}
  defp direction_bound_attrs([zero, one]) do
    %{0 => add_direction_suffix(zero), 1 => add_direction_suffix(one)}
  end

  @spec add_direction_suffix(String.t()) :: String.t()
  defp add_direction_suffix("North"), do: "Northbound"
  defp add_direction_suffix("South"), do: "Southbound"
  defp add_direction_suffix("East"), do: "Eastbound"
  defp add_direction_suffix("West"), do: "Westbound"
  defp add_direction_suffix(nil), do: ""
  defp add_direction_suffix(name), do: name

  @spec parse_gtfs_desc(String.t()) :: Route.gtfs_route_desc()
  defp parse_gtfs_desc(description)
  defp parse_gtfs_desc("Airport Shuttle"), do: :airport_shuttle
  defp parse_gtfs_desc("Commuter Rail"), do: :commuter_rail
  defp parse_gtfs_desc("Rapid Transit"), do: :rapid_transit
  defp parse_gtfs_desc("Local Bus"), do: :local_bus
  defp parse_gtfs_desc("Ferry"), do: :ferry
  defp parse_gtfs_desc("Rail Replacement Bus"), do: :rail_replacement_bus
  defp parse_gtfs_desc("Key Bus"), do: :key_bus_route
  defp parse_gtfs_desc("Supplemental Bus"), do: :supplemental_bus
  defp parse_gtfs_desc("Commuter Bus"), do: :commuter_bus
  defp parse_gtfs_desc("Community Bus"), do: :community_bus
  defp parse_gtfs_desc("Limited Service"), do: :limited_service
  defp parse_gtfs_desc("Express Bus"), do: :express_bus
  defp parse_gtfs_desc("Key Bus Route (Frequent Service)"), do: :key_bus_route
  defp parse_gtfs_desc(_), do: :unknown

  @spec parse_shape(Item.t()) :: [Shape.t()]
  def parse_shape(%Item{id: id, attributes: attributes, relationships: relationships}) do
    [
      %Shape{
        id: id,
        name: attributes["name"],
        stop_ids: Enum.map(relationships["stops"], & &1.id),
        direction_id: attributes["direction_id"],
        polyline: attributes["polyline"],
        priority: attributes["priority"]
      }
    ]
  end
end
