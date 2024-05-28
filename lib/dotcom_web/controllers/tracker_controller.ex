defmodule DotcomWeb.TrackerController do
  @moduledoc """
  Along with tracker.js, this controller logs the path and session_id of the user.
  It allows us to see what pages are being visited in a session.
  """

  use DotcomWeb, :controller

  require Logger

  def tracker(conn, _params) do
    if Plug.Conn.get_req_header(conn, "user-agent") != ["Playwright"] do
      maybe_log(conn)
    end

    conn
    |> send_resp(200, "ok")
    |> halt
  end

  defp maybe_log(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, _body, conn} ->
        %{"path" => path, "session_id" => session_id} = conn.body_params

        Logger.notice("#{__MODULE__} session_id=#{session_id} path=#{path} ")

      _ ->
        nil
    end
  end
end
