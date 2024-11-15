defmodule DotcomWeb.Plug.Mticket do
  @moduledoc """

  A module Plug to detect requests coming from the old mTicket app and send a different HTML response
  with a simlple page containing a notification.

  This plug is only called from the mode and schedule controllers because only two routes are currently
  being proxied by mTicket.

  There is no attempt to automatically redirect the user because these endpoints are called when
  mTicket loads, not when the Schedules or Alerts button is clicked in the app.

  """

  import Phoenix.Controller, only: [put_layout: 2, put_view: 2, render: 3]
  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    # this is the user agent that mTrip 1.0 uses to proxy some pages when the app is first loaded
    if get_req_header(conn, "user-agent") == ["Java/1.8.0_91"] do
      content_description =
        if String.contains?(conn.request_path, "schedule"), do: "schedules", else: "alerts"

      full_link_path = "#{DotcomWeb.Endpoint.url()}#{conn.request_path}"

      conn
      |> put_layout(false)
      |> put_view(DotcomWeb.MticketView)
      |> render(
        "notice.html",
        full_link_path: full_link_path,
        content_description: content_description
      )
      |> halt
    else
      conn
    end
  end
end
