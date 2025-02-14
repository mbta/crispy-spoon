defmodule Dotcom.SystemStatus.Alerts do
  @moduledoc """
  A utility module intended to filter alerts for the system status feature,
  relying on some specific criteria that are specific enough that they don't
  belong in the main `Alerts` module.
  """

  import Dotcom.Alerts, only: [service_impacting_alert?: 1]

  @type service_effect_t :: :delay | :shuttle | :suspension | :station_closure

  @doc """
  Returns `true` if the alert is active at some point during the day
  given, unless the alert's end time is before the time given.

  This is primarily intended to be called with `now` as the time
  passed in, so that it effectively says whether an alert is relevant
  for a commuter now or later today.

  ## Example (Currently Active)
      iex> now = Timex.to_datetime(~N[2025-01-05 14:00:00], "America/New_York")
      iex> one_hour_ago = Timex.to_datetime(~N[2025-01-05 13:00:00], "America/New_York")
      iex> one_hour_from_now = Timex.to_datetime(~N[2025-01-05 15:00:00], "America/New_York")
      iex> Dotcom.SystemStatus.Alerts.active_on_day?(
      ...>   %Alerts.Alert{active_period: [{one_hour_ago, one_hour_from_now}]},
      ...>   now
      ...> )
      true

  ## Example (Active Later Today)
      iex> now = Timex.to_datetime(~N[2025-01-05 14:00:00], "America/New_York")
      iex> one_hour_from_now = Timex.to_datetime(~N[2025-01-05 15:00:00], "America/New_York")
      iex> one_day_from_now = Timex.to_datetime(~N[2025-01-06 14:00:00], "America/New_York")
      iex> Dotcom.SystemStatus.Alerts.active_on_day?(
      ...>   %Alerts.Alert{active_period: [{one_hour_from_now, one_day_from_now}]},
      ...>   now
      ...> )
      true

  Returns `false` for alerts that are either closed out or too far in
  the future.

  ## Example (Expired)
      iex> now = Timex.to_datetime(~N[2025-01-05 14:00:00], "America/New_York")
      iex> two_hours_ago = Timex.to_datetime(~N[2025-01-05 12:00:00], "America/New_York")
      iex> one_hour_ago = Timex.to_datetime(~N[2025-01-05 13:00:00], "America/New_York")
      iex> Dotcom.SystemStatus.Alerts.active_on_day?(
      ...>   %Alerts.Alert{active_period: [{two_hours_ago, one_hour_ago}]},
      ...>   now
      ...> )
      false

  ## Example (Not Active Until Tomorrow)
      iex> now = Timex.to_datetime(~N[2025-01-05 14:00:00], "America/New_York")
      iex> one_day_from_now = Timex.to_datetime(~N[2025-01-06 14:00:00], "America/New_York")
      iex> two_days_from_now = Timex.to_datetime(~N[2025-01-07 14:00:00], "America/New_York")
      iex> Dotcom.SystemStatus.Alerts.active_on_day?(
      ...>   %Alerts.Alert{active_period: [{one_day_from_now, two_days_from_now}]},
      ...>   now
      ...> )
      false
  """
  def active_on_day?(alert, datetime) do
    Enum.any?(alert.active_period, fn {active_period_start, active_period_end} ->
      starts_before_end_of_service?(active_period_start, datetime) &&
        has_not_ended?(active_period_end, datetime)
    end)
  end

  @doc """
  Given a list of alerts, filters only the ones that are active today, as defined in `active_on_day?/2`.
  """
  def for_day(alerts, datetime) do
    Enum.filter(alerts, &active_on_day?(&1, datetime))
  end

  @doc """
  Given a list of alerts, returns only the alerts whose effects are one of
  `[:delay, :shuttle, :suspension, :station_closure]`.

  ## Examples
      iex> alerts = [
      ...>   %Alerts.Alert{id: "include_this", effect: :delay},
      ...>   %Alerts.Alert{id: "exclude_this", effect: :escalator_closure}
      ...> ]
      iex> Dotcom.SystemStatus.Alerts.filter_relevant(alerts) |> Enum.map(& &1.id)
      ["include_this"]
  }
  """
  def filter_relevant(alerts) do
    alerts |> Enum.filter(&service_impacting_alert?/1)
  end

  # Returns true if the alert (as signified by the active_period_start provided)
  # starts before the end of datetime's day.
  defp starts_before_end_of_service?(active_period_start, datetime) do
    datetime |> Util.end_of_service() |> Timex.after?(active_period_start)
  end

  # Returns true if the alert (as signified by the active_period_end provided)
  # ends before the given datetime. If active_period_end is nil, then the alert
  # is indefinite, which means that it definitionally has not ended.
  defp has_not_ended?(nil, _datetime), do: true

  defp has_not_ended?(active_period_end, datetime),
    do: datetime |> Timex.before?(active_period_end)
end
