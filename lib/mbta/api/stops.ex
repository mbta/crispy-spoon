defmodule MBTA.Api.Stops do
  @moduledoc """
  Responsible for fetching Stop data from the V3 API.
  """

  @mbta_api Application.compile_env!(:dotcom, :mbta_api)

  def all(params \\ []) do
    @mbta_api.get_json("/stops/", params)
  end

  def by_gtfs_id(gtfs_id, params, opts \\ []) do
    @mbta_api.get_json(
      "/stops/#{gtfs_id}",
      params,
      opts
    )
  end
end
