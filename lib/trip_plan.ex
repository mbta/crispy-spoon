defmodule TripPlan do
  @moduledoc """
  Plan transit trips from one place to another.
  """
  alias Util.Position

  @doc """
  Tries to describe how to get between two places.
  """
  @spec plan(
          Position.t(),
          Position.t(),
          TripPlan.Api.connection_opts(),
          TripPlan.Api.plan_opts()
        ) :: TripPlan.Api.t()
  def plan(from, to, connection_opts, opts) do
    apply(module(TripPlanApi), :plan, [
      from,
      to,
      connection_opts,
      opts
    ])
  end

  @doc """
  Finds the latitude/longitude for a given address.
  """
  @spec geocode(String.t()) :: TripPlan.Geocode.t()
  def geocode(address)

  def geocode("") do
    {:error, :required}
  end

  def geocode(address) when is_binary(address) do
    apply(module(TripPlanGeocode), :geocode, [address])
  end

  defp module(sub_module), do: Application.fetch_env!(:dotcom, sub_module)[:module]
end
