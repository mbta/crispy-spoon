defmodule SiteWeb.Plugs.RewriteUrls do
  @moduledoc """
  Plug to redirect before other kinds of data are loaded.

  Currently, only used to redirect from the old Boat-F3 (Hull Ferry) schedule
  to the new Boat-F1 (Hingham/Hull Ferry) schedule.
  """
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  @impl true
  def init([]), do: []

  @impl true
  def call(conn, _) do
    if new_base_url = rewrite_url(conn) do
      conn
      |> redirect(to: merge_url(new_base_url, conn.query_string))
      |> halt
    else
      conn
    end
  end

  defp rewrite_url(%{path_info: ["schedules", "Boat-F3" | _]} = conn) do
    String.replace(conn.request_path, "Boat-F3", "Boat-F1")
  end

  # defp rewrite_url(%{path_info: ["schedules", "62" | _]} = conn) do
  #   String.replace(conn.request_path, "62", "627")
  # end

  # defp rewrite_url(%{path_info: ["schedules", "76" | _]} = conn) do
  #   String.replace(conn.request_path, "76", "627")
  # end

  defp rewrite_url(_conn) do
    nil
  end

  defp merge_url(base_url, "") do
    base_url
  end

  defp merge_url(base_url, query_string) do
    "#{base_url}?#{query_string}"
  end
end
