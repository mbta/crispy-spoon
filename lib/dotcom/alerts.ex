defmodule Dotcom.Alerts do
  @moduledoc """
  A collection of functions that help to work with alerts in a unified way.
  """

  alias Alerts.Alert

  @service_impacting_effects [:delay, :shuttle, :suspension, :station_closure]

  @doc """
  Does the alert have an effect that is considered service-impacting?
  """
  @spec service_impacting_alert?(Alert.t()) :: boolean()
  def service_impacting_alert?(%Alert{effect: effect}) do
    effect in @service_impacting_effects
  end

  @doc """
  Returns a list of the alert effects that are considered service-impacting.
  """
  @spec service_impacting_effects() :: [atom()]
  def service_impacting_effects(), do: @service_impacting_effects
end
