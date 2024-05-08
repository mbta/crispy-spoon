defmodule DotcomWeb.Telemetry do
  @moduledoc """
  This module is responsible for starting the Telemetry poller and defining the metrics to be collected for Phoenix and the Erlang VM.
  """

  use Supervisor

  alias Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    telemetry_metrics_splunk_config = Application.get_env(:dotcom, :telemetry_metrics_splunk)

    children = [
      {
        TelemetryMetricsSplunk,
        [
          metrics: metrics(),
          token: telemetry_metrics_splunk_config[:token],
          url: telemetry_metrics_splunk_config[:url]
        ]
      },
      {
        :telemetry_poller,
        measurements: measurements(), period: :timer.seconds(60), init_delay: :timer.seconds(5)
      },
      {DotcomWeb.Stats, %{}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp measurements do
    [
      {DotcomWeb.Stats, :dispatch_stats, []}
    ]
  end

  defp metrics do
    [
      Metrics.last_value("dotcom_web.request.count"),
      Metrics.last_value("dotcom_web.request.avg")
    ]
  end
end
