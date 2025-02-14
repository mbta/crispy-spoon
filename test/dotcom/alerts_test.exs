defmodule Dotcom.AlertsTest do
  use ExUnit.Case

  import Dotcom.Alerts

  describe "service_impacting_alert?/1" do
    test "returns true if the alert has an effect that is considered service-impacting" do
      # Setup
      effect = service_impacting_effects() |> Faker.Util.pick()
      alert = %Alerts.Alert{effect: effect}

      # Exercise/Verify
      assert service_impacting_alert?(alert)
    end

    test "returns false if the alert does not have an effect that is considered service-impacting" do
      # Setup
      alert = %Alerts.Alert{effect: :not_service_impacting}

      # Exercise/Verify
      refute service_impacting_alert?(alert)
    end
  end

  describe "service_impacting_effects/0" do
    test "returns a list of the alert effects as atoms" do
      # Exercise/Verify
      assert Enum.all?(service_impacting_effects(), &is_atom/1)
    end
  end
end
