defmodule Alerts.Cache.Fetcher do
  @moduledoc """
  A fetcher process which periodically hits an API and updates a cache store.
  The fetcher uses DI to allow swapping in different API and store functions, but the
  default functions are MBTA.Api.Alerts.all() and Alerts.Cache.Store.update().

  If an API call fails, then the store is not modified.
  """

  use GenServer

  require Logger

  alias Alerts.{Cache, Parser}

  @default_opts [
    api_mfa:
      {MBTA.Api.Alerts, :all,
       [
         [
           "filter[activity]": "ALL"
         ]
       ]},
    repeat_ms: 60_000,
    update_fn: &Cache.Store.update/2
  ]

  # Client

  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    GenServer.start_link(__MODULE__, opts)
  end

  # Server
  @impl true
  def init(opts) do
    update_fn = Keyword.get(opts, :update_fn)
    api_mfa = Keyword.get(opts, :api_mfa)
    repeat_ms = Keyword.get(opts, :repeat_ms)

    schedule_fetch(1_000)

    {:ok, {update_fn, api_mfa, repeat_ms}}
  end

  @impl true
  def handle_info(:fetch, {update_fn, api_mfa, repeat_ms} = state) do
    case api_result(api_mfa) do
      %{data: data} ->
        alerts = Enum.map(data, &Parser.Alert.parse/1)

        banner =
          data
          |> Enum.flat_map(&Parser.Banner.parse/1)
          |> List.first()

        update_fn.(alerts, banner)

      {:error, msg} ->
        _ = Logger.info("#{__MODULE__} error fetching alerts: #{inspect(msg)}")
    end

    schedule_fetch(repeat_ms)

    {:noreply, state, :hibernate}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp api_result({module, fun, args}) do
    apply(module, fun, args)
  end

  defp schedule_fetch(ms) do
    Process.send_after(self(), :fetch, ms)
  end
end
