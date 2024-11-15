defmodule DotcomWeb.WwwRedirector do
  @moduledoc """
  Enables redirecting obsolete subdomains to www.mbta.com.

  ## Example

  Redirect all paths for `obsolete.mbta.com`:

  ```elixir
  scope "/", DotcomWeb, host: "obsolete." do
    get("/*path", WwwRedirector, [])
  end
  ```
  """

  import Phoenix.Controller, only: [redirect: 2]
  import Plug.Conn, only: [put_status: 2, halt: 1]

  alias Plug.Conn

  @behaviour Plug

  @impl true
  def init([]), do: []

  @impl true
  def call(conn, _options), do: site_redirect(DotcomWeb.Endpoint.url(), conn)

  @spec site_redirect(String.t(), Conn.t()) :: Plug.Conn.t()
  def site_redirect(site_url, conn) do
    full_redirect_url = redirect_url(site_url, conn)

    conn
    |> put_status(:moved_permanently)
    |> redirect(external: full_redirect_url)
    |> halt()
  end

  defp redirect_url(site_url, %Conn{request_path: path, query_string: query})
       when is_binary(query) and query != "" do
    "#{site_url}#{path}?#{query}"
  end

  defp redirect_url(site_url, %Conn{request_path: path}) do
    "#{site_url}#{path}"
  end
end
