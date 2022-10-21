defmodule Alerts.Parser do
  @moduledoc """
  This is the logic for parsing the different alerts on the website.
  """
  defmodule Alert do
    @moduledoc """
    This is the module to parse alerts
    """
    @spec parse(JsonApi.Item.t()) :: Alerts.Alert.t()
    def parse(%JsonApi.Item{type: "alert", id: id, attributes: attributes}) do
      Alerts.Alert.new(
        id: id,
        header: attributes["header"],
        informed_entity: parse_informed_entity(attributes["informed_entity"]),
        active_period: Enum.map(attributes["active_period"], &active_period/1),
        effect: effect(attributes),
        severity: severity(attributes["severity"]),
        lifecycle: lifecycle(attributes["lifecycle"]),
        updated_at: parse_time(attributes["updated_at"]),
        description: description(attributes["description"]),
        url: description(attributes["url"])
      )
    end

    def parse_informed_entity(informed_entities) do
      informed_entities
      |> Enum.flat_map(&informed_entity/1)
      |> Enum.uniq()
    end

    defp informed_entity(%{"route" => "Green" <> _} = entity) do
      [do_informed_entity(entity), do_informed_entity(%{entity | "route" => "Green"})]
    end

    defp informed_entity(entity) do
      [do_informed_entity(entity)]
    end

    defp do_informed_entity(entity) do
      # since lookups default to nil, this results in the correct data
      %Alerts.InformedEntity{
        route_type: entity["route_type"],
        route: entity["route"],
        stop: entity["stop"],
        trip: entity["trip"],
        direction_id: entity["direction_id"],
        activities: MapSet.new(Enum.map(entity["activities"], &do_activity/1))
      }
    end

    @spec do_activity(String.t()) :: Alerts.InformedEntity.activity_type()
    defp do_activity("BOARD"), do: :board
    defp do_activity("EXIT"), do: :exit
    defp do_activity("RIDE"), do: :ride
    defp do_activity("PARK_CAR"), do: :park_car
    defp do_activity("STORE_BIKE"), do: :store_bike
    defp do_activity("BRINGING_BIKE"), do: :bringing_bike
    defp do_activity("USING_WHEELCHAIR"), do: :using_wheelchair
    defp do_activity("USING_ESCALATOR"), do: :using_escalator
    defp do_activity(_), do: :unknown

    defp active_period(%{"start" => start, "end" => stop}) do
      {parse_time(start), parse_time(stop)}
    end

    defp parse_time(nil) do
      nil
    end

    defp parse_time(str) do
      str
      |> Timex.parse!("{ISO:Extended}")
    end

    # remove leading/trailing whitespace from description
    defp description(nil) do
      nil
    end

    defp description(str) do
      case String.trim(str) do
        "" -> nil
        str -> str
      end
    end

    @spec effect(%{String.t() => String.t()}) :: Alerts.Alert.effect()
    def effect(attributes) do
      case Map.fetch(attributes, "effect_name") do
        {:ok, effect_name} ->
          effect_name
          |> String.replace(" ", "_")
          |> String.upcase()
          |> do_effect()

        :error ->
          attributes
          |> Map.get("effect")
          |> do_effect()
      end
    end

    @spec do_effect(String.t()) :: Alerts.Alert.effect()
    defp do_effect("AMBER_ALERT"), do: :amber_alert
    defp do_effect("CANCELLATION"), do: :cancellation
    defp do_effect("DELAY"), do: :delay
    defp do_effect("SUSPENSION"), do: :suspension
    defp do_effect("TRACK_CHANGE"), do: :track_change
    defp do_effect("DETOUR"), do: :detour
    defp do_effect("SHUTTLE"), do: :shuttle
    defp do_effect("STOP_CLOSURE"), do: :stop_closure
    defp do_effect("DOCK_CLOSURE"), do: :dock_closure
    defp do_effect("STATION_CLOSURE"), do: :station_closure
    # previous configuration
    defp do_effect("STOP_MOVE"), do: :stop_moved
    defp do_effect("STOP_MOVED"), do: :stop_moved
    defp do_effect("EXTRA_SERVICE"), do: :extra_service
    defp do_effect("SCHEDULE_CHANGE"), do: :schedule_change
    defp do_effect("SERVICE_CHANGE"), do: :service_change
    defp do_effect("SNOW_ROUTE"), do: :snow_route
    defp do_effect("STATION_ISSUE"), do: :station_issue
    defp do_effect("DOCK_ISSUE"), do: :dock_issue
    defp do_effect("ACCESS_ISSUE"), do: :access_issue
    defp do_effect("FACILITY_ISSUE"), do: :facility_issue
    defp do_effect("BIKE_ISSUE"), do: :bike_issue
    defp do_effect("PARKING_ISSUE"), do: :parking_issue
    defp do_effect("PARKING_CLOSURE"), do: :parking_closure
    defp do_effect("ELEVATOR_CLOSURE"), do: :elevator_closure
    defp do_effect("ESCALATOR_CLOSURE"), do: :escalator_closure
    defp do_effect("POLICY_CHANGE"), do: :policy_change
    defp do_effect("STOP_SHOVELING"), do: :stop_shoveling
    defp do_effect("SUMMARY"), do: :summary
    defp do_effect(_), do: :unknown

    @spec severity(String.t() | integer) :: Alerts.Alert.severity()
    def severity(binary) when is_binary(binary) do
      case String.upcase(binary) do
        "INFORMATION" ->
          1

        "MINOR" ->
          3

        "MODERATE" ->
          5

        "SIGNIFICANT" ->
          6

        "SEVERE" ->
          7

        # default to moderate
        _ ->
          5
      end
    end

    def severity(int) when 0 <= int and int <= 10 do
      int
    end

    @spec lifecycle(String.t()) :: Alerts.Alert.lifecycle()
    def lifecycle(binary) do
      case String.upcase(binary) do
        "ONGOING" ->
          :ongoing

        "UPCOMING" ->
          :upcoming

        # could be either "ONGOING_UPCOMING" or "ONGOING UPCOMING"
        "ONGOING" <> _ ->
          :ongoing_upcoming

        "NEW" ->
          :new

        _ ->
          :unknown
      end
    end
  end

  defmodule Banner do
    @moduledoc """
    This is the module to parse the banner
    """
    alias Alerts.{Banner, InformedEntitySet, Parser.Alert}

    @spec parse(JsonApi.Item.t()) :: [Banner.t()]
    def parse(%JsonApi.Item{
          id: id,
          attributes:
            %{
              "url" => url,
              "banner" => title,
              "severity" => severity,
              "informed_entity" => informed_entity
            } = attributes
        })
        when title != nil and url != nil do
      [
        %Banner{
          id: id,
          title: title,
          url: url,
          url_parsed_out_of_title: false,
          effect: Alert.effect(attributes),
          severity: Alert.severity(severity),
          informed_entity_set:
            informed_entity |> Alert.parse_informed_entity() |> InformedEntitySet.new()
        }
      ]
    end

    def parse(%JsonApi.Item{
          id: id,
          attributes:
            %{
              "url" => url,
              "banner" => title,
              "severity" => severity,
              "informed_entity" => informed_entity
            } = attributes
        })
        when title != nil and url == nil do
      parsed_url = Alerts.URLParsingHelpers.get_full_url(title)

      [
        %Banner{
          id: id,
          title: title,
          url: parsed_url,
          url_parsed_out_of_title: parsed_url != nil,
          effect: Alert.effect(attributes),
          severity: Alert.severity(severity),
          informed_entity_set:
            informed_entity |> Alert.parse_informed_entity() |> InformedEntitySet.new()
        }
      ]
    end

    def parse(%JsonApi.Item{}) do
      []
    end
  end
end
