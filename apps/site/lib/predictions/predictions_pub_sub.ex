defmodule Predictions.PredictionsPubSub do
  @moduledoc """
  Allow channels to subscribe to prediction streams, which are collected into an
  ETS table keyed by prediction ID, route ID, stop ID, direction ID, trip ID,
  and vehicle ID for easy retrieval.

  Set up to broadcast predictions periodically, or can be broadcast on-demand.
  """

  use GenServer

  alias Predictions.{Prediction, Store, StreamTopic, StreamSupervisor}

  @broadcast_interval_ms Application.compile_env!(:site, [:predictions_broadcast_interval_ms])
  @subscribers :prediction_subscriptions_registry

  @type registry_value :: {Store.fetch_keys(), binary()}
  @type broadcast_message :: {:new_predictions, [Prediction.t()]}

  # Client

  @spec start_link() :: GenServer.on_start()
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(
      __MODULE__,
      opts,
      name: name
    )
  end

  @spec subscribe(String.t()) :: [Prediction.t()]
  @spec subscribe(String.t(), GenServer.server()) :: [Prediction.t()] | {:error, term()}
  def subscribe(topic, server \\ __MODULE__) do
    with %StreamTopic{} = stream_topic <- StreamTopic.new(topic) do
      :ok = StreamTopic.start_streams(stream_topic)

      {registry_key, predictions} = GenServer.call(server, {:subscribe, stream_topic})

      for key <- StreamTopic.registration_keys(stream_topic) do
        Registry.register(@subscribers, registry_key, key)
      end

      predictions
    else
      {:error, _} = error ->
        error
    end
  end

  # Server

  @impl GenServer
  def init(opts) do
    subscribe_fn = Keyword.get(opts, :subscribe_fn, &Phoenix.PubSub.subscribe/2)
    subscribe_fn.(Predictions.PubSub, "predictions")
    broadcast_timer(50)

    callers = :ets.new(:callers_by_pid, [:bag])
    dispatched = :ets.new(:last_dispatched, [:set])

    {:ok,
     %{
       callers_by_pid: callers,
       last_dispatched: dispatched
     }}
  end

  @impl GenServer
  def handle_call(
        {:subscribe,
         %StreamTopic{
           fetch_keys: fetch_keys,
           streams: streams
         }},
        {from_pid, _ref},
        state
      ) do
    filter_names = Enum.map(streams, &elem(&1, 1))
    :ets.insert(state.callers_by_pid, Enum.map(filter_names, &{from_pid, &1}))
    registry_key = self()
    {:reply, {registry_key, Store.fetch(fetch_keys)}, state, :hibernate}
  end

  @impl GenServer
  def handle_cast({:closed_channel, caller_pid}, state) do
    # Here we can check if there are other subscribers for the associated key.
    # If there are no other subscribers remaining, we stop the associated
    # predictions data stream.
    :ets.lookup(state.callers_by_pid, caller_pid)
    |> Enum.each(fn {_, filter_name} ->
      other_pids_for_filter =
        :ets.select(state.callers_by_pid, [
          {{:"$1", filter_name}, [{:"=/=", :"$1", caller_pid}], [:"$1"]}
        ])

      if length(other_pids_for_filter) == 0 do
        StreamSupervisor.stop_stream(filter_name)
      end
    end)

    :ets.delete(state.callers_by_pid, caller_pid)
    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def handle_info(:broadcast, state) do
    registry_key = self()

    Registry.dispatch(@subscribers, registry_key, fn entries ->
      Enum.group_by(
        entries,
        fn {_, {fetch_keys, _}} -> fetch_keys end,
        fn {pid, {_, _}} -> pid end
      )
      |> Enum.each(fn {fetch_keys, pids} ->
        new_predictions = Store.fetch(fetch_keys)
        send(self(), {:dispatch, Enum.uniq(pids), fetch_keys, new_predictions})
      end)
    end)

    {:noreply, state, :hibernate}
  end

  def handle_info(:timed_broadcast, state) do
    send(self(), :broadcast)
    broadcast_timer()
    {:noreply, state, :hibernate}
  end

  def handle_info(
        {:dispatch, pids, fetch_keys, predictions},
        state
      ) do
    if :ets.lookup(state.last_dispatched, fetch_keys) != predictions do
      Enum.each(pids, &send(&1, {:new_predictions, predictions}))
      :ets.insert(state.last_dispatched, {fetch_keys, predictions})
    end

    {:noreply, state, :hibernate}
  end

  defp broadcast_timer(interval \\ @broadcast_interval_ms) do
    Process.send_after(self(), :timed_broadcast, interval)
  end
end
