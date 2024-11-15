defmodule DotcomWeb.Plugs.BannerMessage do
  @moduledoc """
  Assigns a message to `conn` using the following params:
  - `message_key` is the key that will be used to retrieve the message.
  - `message` is a map representing the actual message.
  """

  import Plug.Conn, only: [assign: 3]

  @behaviour Plug

  @impl true
  def init(opts) do
    opts
  end

  @impl true
  def call(conn, message_key: message_key, message: message) do
    assign(conn, message_key, message)
  end

  def call(conn, _), do: conn
end
