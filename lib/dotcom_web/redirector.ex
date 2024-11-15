defmodule DotcomWeb.Redirector do
  import Plug.Conn, only: [put_status: 2, halt: 1]
  import Phoenix.Controller, only: [redirect: 2]

  alias CMS.Repo

  @behaviour Plug

  @impl true

  @spec init(Keyword.t()) :: Keyword.t()
  def init([to: _] = opts), do: opts
  def init(_default), do: raise("Missing required to: option in redirect")

  @impl true
  @spec call(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def call(%Plug.Conn{params: %{"id" => id}} = conn, to: to) when to not in ["/projects"] do
    case find_record(id, to) do
      :not_found -> DotcomWeb.ControllerHelpers.render_404(conn)
      record -> redirect_to_show(conn, to, record)
    end
  end

  def call(conn, to: to) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: append_query_string(conn, to))
    |> halt()
  end

  defp append_query_string(%Plug.Conn{query_string: ""}, path), do: path
  defp append_query_string(%Plug.Conn{query_string: query}, path), do: "#{path}?#{query}"

  defp find_record(id, "/events") do
    Repo.event_by(meeting_id: id)
  end

  defp find_record(id, "/news") do
    Repo.news_entry_by(migration_id: id)
  end

  defp redirect_to_show(conn, to, record) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: to <> "/#{record.id}")
    |> halt()
  end
end
