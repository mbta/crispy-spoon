defmodule DotcomWeb.Plugs.ScheduleRedirector do
  @moduledoc """
  Catch-all for unsupported `/schedules/:route_id/*` URLs.
  Redirects to the default `/schedules/:route_id` path.
  """

  import DotcomWeb.Router.Helpers, only: [schedule_path: 3]
  import Phoenix.Controller, only: [redirect: 2]

  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{path_info: ["schedules", route_id | _]} = conn, _opts) do
    conn
    |> redirect(to: schedule_path(conn, :show, route_id))
    |> Conn.halt()
  end

  def call(conn, _opts), do: conn
end
