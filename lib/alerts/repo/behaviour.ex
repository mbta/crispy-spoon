defmodule Alerts.Repo.Behaviour do
  @moduledoc """
  Behaviour for the Alerts repo.
  """

  @doc """
  Return all alerts for the given route ids.
  """
  @callback by_route_ids([String.t()], DateTime.t()) :: [Alert.t()]
end
