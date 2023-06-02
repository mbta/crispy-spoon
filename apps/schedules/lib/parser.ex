defmodule Schedules.Parser do
  alias JsonApi.Item
  alias Routes.Route
  alias Stops.Stop

  @type record :: {
          route_id :: Route.id_t(),
          trip_id :: String.t(),
          stop_id :: Stop.id_t(),
          arrival_time :: DateTime.t() | nil,
          departure_time :: DateTime.t() | nil,
          time :: DateTime.t(),
          flag? :: boolean,
          early_departure? :: boolean,
          last_stop? :: boolean,
          stop_sequence :: integer,
          pickup_type :: integer
        }

  @spec parse(Item.t()) :: record
  def parse(item) do
    {
      route_id(item),
      trip_id(item),
      stop_id(item),
      arrival_time(item),
      departure_time(item),
      time(item),
      flag?(item),
      early_departure?(item),
      last_stop?(item),
      item.attributes["stop_sequence"] || 0,
      pickup_type(item)
    }
  end

  def route_id(%JsonApi.Item{relationships: %{"route" => [%JsonApi.Item{id: id} | _]}}) do
    id
  end

  def trip_id(%JsonApi.Item{relationships: %{"trip" => [%JsonApi.Item{id: id} | _]}}) do
    id
  end

  def trip(%JsonApi.Item{
        relationships: %{
          "trip" => [
            %JsonApi.Item{
              id: id,
              attributes:
                %{"name" => name, "headsign" => headsign, "direction_id" => direction_id} =
                  attributes,
              relationships: relationships
            }
            | _
          ]
        }
      }) do
    %Schedules.Trip{
      id: id,
      headsign: headsign,
      name: name,
      direction_id: direction_id,
      bikes_allowed?: bikes_allowed?(attributes),
      route_pattern_id: route_pattern_id(relationships),
      shape_id: shape_id(relationships),
      occupancy: occupancy(relationships)
    }
  end

  def trip(%JsonApi{
        data: [
          %JsonApi.Item{
            id: id,
            attributes:
              %{
                "headsign" => headsign,
                "name" => name,
                "direction_id" => direction_id
              } = attributes,
            relationships: relationships
          }
        ]
      }) do
    %Schedules.Trip{
      id: id,
      headsign: headsign,
      name: name,
      direction_id: direction_id,
      shape_id: shape_id(relationships),
      route_pattern_id: route_pattern_id(relationships),
      bikes_allowed?: bikes_allowed?(attributes),
      occupancy: occupancy(relationships)
    }
  end

  def trip(%JsonApi.Item{relationships: %{"trip" => _}}) do
    nil
  end

  def stop_id(%JsonApi.Item{
        relationships: %{
          "stop" => [
            %JsonApi.Item{id: id}
          ]
        }
      }) do
    id
  end

  defp arrival_time(%JsonApi.Item{attributes: %{"arrival_time" => time}}) when time != nil do
    Timex.parse!(time, "{ISO:Extended}")
  end

  defp arrival_time(_), do: nil

  defp departure_time(%JsonApi.Item{attributes: %{"departure_time" => time}}) when time != nil do
    Timex.parse!(time, "{ISO:Extended}")
  end

  defp departure_time(_), do: nil

  defp time(%JsonApi.Item{attributes: %{"departure_time" => nil, "arrival_time" => time}}) do
    Timex.parse!(time, "{ISO:Extended}")
  end

  defp time(%JsonApi.Item{attributes: %{"departure_time" => time}}) do
    Timex.parse!(time, "{ISO:Extended}")
  end

  defp flag?(%JsonApi.Item{
         attributes: %{"pickup_type" => pickup_type, "drop_off_type" => drop_off_type}
       }) do
    # https://developers.google.com/transit/gtfs/reference/stop_times-file
    # defines pickup_type and drop_off_type:
    # * 0: Regularly scheduled drop off
    # * 1: No drop off available
    # * 2: Must phone agency to arrange drop off
    # * 3: Must coordinate with driver to arrange drop off
    # Flag trips are those which need coordination.
    pickup_type == 3 || drop_off_type == 3
  end

  defp early_departure?(%JsonApi.Item{
         attributes: %{"pickup_type" => pickup_type, "timepoint" => timepoint}
       }) do
    # early departure when the timepoint is false and the pickup_type is not 1
    timepoint == false && pickup_type != 1
  end

  defp last_stop?(%JsonApi.Item{
         attributes: %{
           "drop_off_type" => dropoff,
           "pickup_type" => pickup
         }
       }) do
    dropoff === 0 and pickup === 1
  end

  defp pickup_type(%JsonApi.Item{attributes: %{"pickup_type" => pickup_type}}) do
    pickup_type
  end

  @spec shape_id(any) :: String.t() | nil
  defp shape_id(%{"shape" => [%JsonApi.Item{id: id}]}), do: id
  defp shape_id(_), do: nil

  @spec route_pattern_id(any) :: String.t() | nil
  defp route_pattern_id(%{"route_pattern" => [%JsonApi.Item{id: id}]}), do: id
  defp route_pattern_id(_), do: nil

  @spec bikes_allowed?(map) :: boolean
  defp bikes_allowed?(%{"bikes_allowed" => 1}), do: true
  defp bikes_allowed?(_), do: false

  @spec occupancy(any) :: Schedules.Trip.crowding() | nil
  defp occupancy(%{
         "occupancies" => [%JsonApi.Item{attributes: %{"status" => status}}]
       }) do
    case status do
      "MANY_SEATS_AVAILABLE" -> :not_crowded
      "FEW_SEATS_AVAILABLE" -> :some_crowding
      "FULL" -> :crowded
      _ -> nil
    end
  end

  defp occupancy(_), do: nil
end
