defmodule DotcomWeb.Plugs.ClearCookies do
  @moduledoc """
  A module Plug that deletes cookies left over from the old application

  * If there is a cookie that starts with ASPSESSION, it will delete it
    (i.e. set it to "" and set max age to 0)
  * All other cookies are left untouched
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init([]), do: []

  @impl true
  def call(%{cookies: cookies} = conn, _) do
    cookies
    |> Map.keys()
    |> Enum.reduce(conn, &expire_cookie/2)
  end

  @spec expire_cookie(String.t(), Plug.Conn.t()) :: Plug.Conn.t()
  defp expire_cookie("ASPSESSION" <> _ = cookie, conn) do
    conn
    |> put_resp_cookie(cookie, "", max_age: 0)
  end

  defp expire_cookie(_, conn), do: conn
end
