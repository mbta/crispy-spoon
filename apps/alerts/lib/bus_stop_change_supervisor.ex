defmodule Alerts.BusStopChangeSupervisor do
  @moduledoc """
  Supervisor for the alert app's processes for the Bus Stop Change page,
  including fetching and caching alerts. The supervision strategy is rest for
  one - if the fetcher crashes, restart it, but leave the BusStopChangeS3
  RepoCache process alone. If the RepoCache process crashes, restart it all.
  """

  use Supervisor
  alias Alerts.Cache.BusStopChangeS3

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [])
  end

  @impl Supervisor
  def init(_arg) do
    children =
      [
        BusStopChangeS3
      ] ++
        if Application.get_env(:elixir, :start_data_processes) do
          [
            {Alerts.Cache.Fetcher, BusStopChangeS3.fetcher_opts()}
          ]
        else
          []
        end

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
