defmodule Alerts.Cache.BusStopChangeS3 do
  @moduledoc """
  Functionality for writing to/reading from S3. Takes %Alert{} converts them
  into %HistoricalAlert{} before saving.
  """

  use Nebulex.Caching.Decorators

  require Logger

  alias Alerts.{Alert, HistoricalAlert}

  @cache Application.compile_env!(:dotcom, :cache)
  @ttl :timer.hours(24)

  @aws_client Application.compile_env(:dotcom, :aws_client)
  @bucket "mbta-dotcom"

  @doc """
  Arguments for the Alerts.Cache.Fetcher process, Fetches current bus alerts
  hourly, sending the parsed alerts to copy_alerts_to_s3/2
  """
  def fetcher_opts do
    [
      api_mfa:
        {MBTA.Api.Alerts, :all,
         [
           [
             "filter[route_type]": 3,
             "filter[datetime]": "NOW"
           ]
         ]},
      repeat_ms: 3_600_000,
      update_fn: &copy_alerts_to_s3/2
    ]
  end

  @doc """
   Find alerts that qualify as a bus stop closure or stop move, and copy them to
   our S3 bucket. This function is invoked in Alerts.Cache.Fetcher.handle_info/2
   with two arguments, but we only use the first.
  """
  @spec copy_alerts_to_s3([Alert.t()], any) :: :ok
  def copy_alerts_to_s3(bus_alerts, _) do
    case Enum.filter(bus_alerts, &(&1.effect in [:stop_closure, :stop_moved])) do
      [] ->
        :ok

      stop_change_alerts ->
        stop_change_alerts
        |> Enum.sort(&(&1.id >= &2.id))
        |> maybe_write_alerts_to_s3()
    end
  end

  @decorate cacheable(
              cache: @cache,
              key:
                Dotcom.Cache.KeyGenerator.generate(
                  __MODULE__,
                  :maybe_write_alerts_to_s3,
                  Enum.map(stop_change_alerts, & &1.id)
                ),
              on_error: :nothing,
              opts: [ttl: @ttl]
            )
  defp maybe_write_alerts_to_s3(stop_change_alerts) do
    stop_change_alerts
    |> Enum.map(&HistoricalAlert.from_alert/1)
    |> write_alerts()
  end

  @doc """
  Get bus stop change alerts currently stored on S3. Cached per day.
  """
  @spec get_stored_alerts :: [HistoricalAlert.t()]
  @decorate cacheable(
              cache: @cache,
              key:
                Dotcom.Cache.KeyGenerator.generate(
                  __MODULE__,
                  :get_stored_alerts,
                  Util.service_date()
                ),
              on_error: :nothing,
              opts: [ttl: @ttl]
            )
  def get_stored_alerts do
    keys =
      case @aws_client.list_objects(@bucket, bucket_prefix()) do
        {:ok, %{"ListBucketResult" => %{"Contents" => objects}}, %{}} ->
          objects |> Enum.map(& &1["Key"])

        _ ->
          []
      end

    Enum.map(keys, fn key ->
      result =
        @aws_client.get_object(@bucket, key)

      case result do
        {:ok, %{"Body" => alert_data}, _} ->
          decompress_alert(alert_data)

        error ->
          log_result(error, key, "get_stored_alerts")

          nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @spec write_alerts([HistoricalAlert.t()]) :: :ok
  defp write_alerts(alerts) do
    alerts
    |> Enum.map(fn alert ->
      {alert.id, compress_alert(alert)}
    end)
    |> Task.async_stream(
      fn {id, contents} ->
        case @aws_client.put_object(@bucket, "#{bucket_prefix()}/#{id}", %{"Body" => contents}) do
          {:ok, _, _} ->
            :ok

          error ->
            log_result(error, id, "write_alerts")
            error
        end
      end,
      max_concurrency: 10
    )
    |> Stream.run()
  end

  @spec compress_alert(HistoricalAlert.t()) :: binary()
  defp compress_alert(alert) do
    :erlang.term_to_binary(alert, [:compressed])
  end

  @spec decompress_alert(binary()) :: HistoricalAlert.t()
  defp decompress_alert(alert) do
    :erlang.binary_to_term(alert)
  end

  defp log_result({:ok, _, _}, _alert_id, _func_name) do
    :ok
  end

  defp log_result({:error, reason}, alert_id, func_name) do
    Logger.warning(fn ->
      "module=#{__MODULE__} func=#{func_name} alert=#{alert_id} error=#{inspect(reason)}"
    end)
  end

  defp bucket_prefix do
    Application.fetch_env!(:dotcom, :alerts_bus_stop_change_bucket)
  end
end
