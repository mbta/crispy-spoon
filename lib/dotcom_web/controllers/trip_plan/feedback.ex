defmodule DotcomWeb.TripPlan.Feedback do
  @moduledoc """
  Handle submission of the feedback form given with each itinerary returned by
  the trip planner. Saves to the Redis cache with the default TTL of :infinity.
  """

  use DotcomWeb, :controller
  use Nebulex.Caching.Decorators

  require Logger

  alias Dotcom.Cache.TripPlanFeedback.KeyGenerator
  alias DotcomWeb.TripPlan.FeedbackCSV

  @cache Application.compile_env!(:dotcom, :trip_plan_feedback_cache)

  def delete(conn, params), do: cache_and_response(conn, params, :delete)
  def put(conn, params), do: cache_and_response(conn, params, :put)

  def download(conn, _params) do
    data = get_cached_data()

    send_download(conn, {:binary, data},
      content_type: "application/csv",
      filename: "trip_plan_feedback.csv",
      disposition: :attachment
    )
  end

  def get_cached_data do
    @cache.all("dotcom_web.trip_plan.feedback|#{env_name()}*")
    |> @cache.get_all()
    |> Stream.map(&elem(&1, 1))
    |> FeedbackCSV.rows()
  end

  defp env_name do
    System.get_env("SENTRY_ENVIRONMENT", "local")
  end

  defp cache_and_response(conn, params, action) do
    Logger.info("dotcom_web.trip_plan.feedback action=#{action}")

    handle_cache(action, params)

    send_resp(conn, 202, "")
  end

  @decorate cache_evict(cache: @cache, key_generator: KeyGenerator)
  defp handle_cache(:delete, params), do: params

  @decorate cache_put(cache: @cache, key_generator: KeyGenerator)
  defp handle_cache(:put, params), do: params
end
