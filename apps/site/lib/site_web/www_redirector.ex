defmodule SiteWeb.WwwRedirector do
  @behaviour Plug
  import Plug.Conn, only: [put_status: 2, halt: 1]
  import Phoenix.Controller, only: [redirect: 2]

  alias Plug.Conn

  @impl true
  def init(options), do: options

  @impl true
  def call(conn, options) do
    url = Keyword.get(options, :host, SiteWeb.Endpoint.url())
    site_redirect(url, conn)
  end

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
