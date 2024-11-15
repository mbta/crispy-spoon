defmodule Dotcom.GreenLine.Cache do
  @moduledoc """
  This supervised GenServer populates the GreenLine.DateAgent caches.
  By default, it will ensure an agent is running for every date from
  Util.service_date() until Schedules.Repo.end_of_rating().

  It then schedules a message to itself to update all these agents at
  about 7am ET the next morning.
  """

  use GenServer

  require Logger

  alias Dotcom.GreenLine.{CacheSupervisor, DateAgent}

  # Client

  def start_link(opts \\ []) do
    start_date_fn =
      Keyword.get(opts, :start_date_fn, fn -> elem(Schedules.Repo.rating_dates(), 0) end)

    end_date_fn = Keyword.get(opts, :end_date_fn, &Schedules.Repo.end_of_rating/0)
    reset_fn = Keyword.get(opts, :reset_fn, &reset_cache/1)
    name = Keyword.get(opts, :name, :green_line_cache)

    GenServer.start_link(__MODULE__, {start_date_fn, end_date_fn, reset_fn}, name: name)
  end

  # Server

  @impl true
  def init({start_date_fn, end_date_fn, reset_fn}) do
    case System.get_env("WARM_CACHES") do
      "false" -> :ok
      _ -> send(self(), :populate_caches)
    end

    {:ok, {start_date_fn, end_date_fn, reset_fn}}
  end

  @impl true
  def handle_info(:populate_caches, {start_date_fn, end_date_fn, reset_fn} = state) do
    previous_day = Timex.shift(start_date_fn.(), days: -1)

    if pid = CacheSupervisor.lookup(previous_day) do
      DateAgent.stop(pid)
    end

    reset_fn.(nil)
    populate_cache(start_date_fn.(), end_date_fn.(), reset_fn)

    Process.send_after(
      self(),
      :populate_caches,
      next_update_after(Util.now())
    )

    {:noreply, state, :hibernate}
  end

  def handle_info({:reset_again, date}, {_, _, reset_fn} = state) do
    reset_fn.(date)
    {:noreply, state, :hibernate}
  end

  def handle_info(_, state) do
    # no cover
    {:noreply, state}
  end

  @doc """
  Reset (requery the API) a given date's cache. If the API returns an error,
  try again in 30 seconds.
  """
  @spec reset_cache(Date.t() | nil, integer) :: :ok | :error
  def reset_cache(date, try_again_in \\ 30_000) do
    results =
      case CacheSupervisor.lookup(date) do
        nil -> CacheSupervisor.start_child(date)
        pid -> DateAgent.reset(pid, date)
      end

    case results do
      {:error, msg} ->
        _ = Logger.info("#{__MODULE__} reset_cache error for #{date}: #{inspect(msg)}")
        Process.send_after(self(), {:reset_again, date}, try_again_in)
        :error

      _ ->
        :ok
    end
  end

  @doc """
  Calculates the milliseconds between a date and 7am the next day.
  """
  @spec next_update_after(DateTime.t()) :: integer
  def next_update_after(%DateTime{} = now) do
    now
    |> Timex.shift(days: 1)
    |> Timex.beginning_of_day()
    |> Timex.shift(hours: 7)
    |> Timex.diff(now, :milliseconds)
  end

  defp populate_cache(date, nil, reset_fn) do
    # if we don't have an end date, just do today
    reset_fn.(date)
  end

  defp populate_cache(date, last_date, reset_fn) do
    if Timex.before?(date, Timex.shift(last_date, days: 1)) do
      reset_fn.(date)
      populate_cache(Timex.shift(date, days: 1), last_date, reset_fn)
    end
  end
end
