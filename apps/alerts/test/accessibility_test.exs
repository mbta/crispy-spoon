defmodule Alerts.AccessibilityTest do
  use ExUnit.Case

  alias Alerts.Alert

  describe "is_accessibility_alert?/1" do
    test "checks if accessibility alert" do
      alert =
        Alert.new(
          id: "south-station-alert",
          effect: :escalator_closure,
          header: "Escalator Alert 2",
          informed_entity: [%Alerts.InformedEntity{stop: "place-sstat"}]
        )

      assert Alerts.Accessibility.is_accessibility_alert?(alert)
    end
  end

  describe "effect_type_to_group_title/1" do
    test "if human_effect return corresponding string" do
      assert Alerts.Accessibility.effect_type_to_group_title(:snow_route) == "Snow Routes"
    end
  end
end
