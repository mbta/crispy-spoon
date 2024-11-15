defmodule Dotcom.Cache.Subscriber do
  @moduledoc """
  A GenServer that listens for messages about cache operations and actions on them.
  """

  use GenServer

  require Logger

  alias Dotcom.Cache.Publisher

  @cache Application.compile_env!(:dotcom, :cache)
  @channel Publisher.channel()
  @executions %{
    "eviction" => :delete
  }
  @redix_pub_sub Application.compile_env!(:dotcom, :redix_pub_sub)

  def start_link(uuid) do
    GenServer.start_link(__MODULE__, uuid, [])
  end

  @impl GenServer
  @doc """
  Gets the unique id from the Publisher which starts the Subscriber.
  Starts a Redix.PubSub process and subscribes to the channel given by the Publisher.
  """
  def init(uuid) do
    Application.get_env(:dotcom, :redis_config)
    |> @redix_pub_sub.start_link()
    |> subscribe(@channel)

    {:ok, uuid}
  end

  @impl GenServer
  @doc """
  If we get a subscription message, we just return the state.

  If we get a cache eviction message, we check if the message was published from this Elixir node.
  If not, we delete the given key from the Local cache (L1).
  """
  def handle_info({:redix_pubsub, _pid, _ref, :subscribed, %{channel: _}}, uuid) do
    {:noreply, uuid}
  end

  def handle_info(
        {:redix_pubsub, _pid, _ref, :message, %{channel: @channel, payload: message}},
        publisher_id
      ) do
    [command, sender_id | key] = String.split(message, "|")

    if sender_id != publisher_id do
      maybe_execute_command(command, Enum.join(key, "|"))
    end

    {:noreply, publisher_id}
  end

  defp maybe_execute_command(command, key) do
    if function = Map.get(@executions, command) do
      Kernel.apply(@cache, function, [key, [level: 1]])

      Logger.notice("dotcom.cache.multilevel.subscriber.#{command} key=#{key}")
    else
      Logger.warning("dotcom.cache.multilevel.subscriber.unknown_command command=#{command}")
    end
  end

  defp subscribe({:ok, pubsub}, channel) do
    @redix_pub_sub.subscribe(pubsub, channel, self())
  end
end
