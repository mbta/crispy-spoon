defmodule Dotcom.BodyTag do
  @moduledoc """

  Contains the logic for the className of the <body> element.

  Error: We set an error class if we detect that we're rendering an error page.

  mTicket: If the request has the configured mTicket header, sets a class which will disable certain
    UI elements.
  """

  def class_name(conn) do
    [
      javascript_class(),
      mticket_class(conn),
      preview_class(conn)
    ]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join(" ")
  end

  defp javascript_class, do: "no-js"

  @spec mticket_class(Plug.Conn.t()) :: String.t()
  defp mticket_class(%{host: "mticket.mbtace.com"}), do: "mticket"

  defp mticket_class(conn) do
    case conn
         |> Plug.Conn.get_req_header(Application.get_env(:dotcom, __MODULE__)[:mticket_header]) do
      [] -> ""
      _ -> "mticket"
    end
  end

  @spec preview_class(Plug.Conn.t()) :: String.t()
  defp preview_class(%Plug.Conn{query_params: %{"preview" => _, "vid" => _, "nid" => _}}),
    do: "cms-preview"

  defp preview_class(_conn), do: ""
end
