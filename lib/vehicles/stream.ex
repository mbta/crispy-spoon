defmodule Vehicles.Stream do
  @moduledoc """
  Uses MBTA.Api.Stream to subscribe to the MBTA Api and receive events.
  """

  use GenStage

  require Logger

  alias Phoenix.PubSub
  alias Vehicles.Parser

  @type event_type :: :reset | :add | :update | :remove

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    GenStage.start_link(
      __MODULE__,
      opts,
      name: name
    )
  end

  def init(opts) do
    producer_consumer = Keyword.fetch!(opts, :subscribe_to)
    broadcast_fn = Keyword.get(opts, :broadcast_fn, &PubSub.broadcast/3)
    {:consumer, %{broadcast_fn: broadcast_fn}, subscribe_to: [producer_consumer]}
  end

  def handle_events(events, _from, state) do
    :ok = Enum.each(events, &send_event(&1, state.broadcast_fn))
    {:noreply, [], state}
  end

  defp send_event(
         %MBTA.Api.Stream.Event{
           event: :remove,
           data: %JsonApi{data: data}
         },
         broadcast_fn
       ) do
    data
    |> Enum.map(& &1.id)
    |> broadcast(:remove, broadcast_fn)
  end

  defp send_event(
         %MBTA.Api.Stream.Event{
           event: type,
           data: %JsonApi{data: data}
         },
         broadcast_fn
       ) do
    data
    |> Enum.map(&Parser.parse/1)
    |> broadcast(type, broadcast_fn)
  end

  @typep broadcast_fn :: (atom, String.t(), any -> :ok | {:error, any})
  @spec broadcast([Vehicles.Vehicle.t() | String.t()], event_type, broadcast_fn) :: :ok
  defp broadcast(data, type, broadcast_fn) do
    Vehicles.PubSub
    |> broadcast_fn.("vehicles", {type, data})
    |> do_broadcast()
  end

  @spec do_broadcast(:ok | {:error, any}) :: :ok
  defp do_broadcast(:ok) do
    :ok
  end

  defp do_broadcast({:error, error}) do
    Logger.error("module=#{__MODULE__} error=#{inspect(error)}")
  end
end
