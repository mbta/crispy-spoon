defmodule Dotcom.BodyTagTest do
  use ExUnit.Case, async: true
  import Dotcom.BodyTag
  import Phoenix.ConnTest, only: [build_conn: 0]
  import Plug.Conn, only: [put_req_header: 3]

  describe "class_name/1" do
    test "returns mticket if the requisite header is present" do
      conn =
        build_conn()
        |> put_req_header(Application.get_env(:dotcom, Dotcom.BodyTag)[:mticket_header], "")

      assert class_name(conn) =~ "no-js mticket"
    end

    test "returns mticket if the site is called as mticket.mbtace.com" do
      conn = %{build_conn() | host: "mticket.mbtace.com"}

      assert class_name(conn) =~ "no-js mticket"
    end

    test "returns 'cms-preview' if page is loaded with CMS ?preview params" do
      conn = %{build_conn() | query_params: %{"preview" => nil, "vid" => "latest", "nid" => "6"}}

      assert class_name(conn) =~ "no-js cms-preview"
    end

    test "does not set 'cms-preview' class if page is loaded with missing CMS &nid param" do
      conn = %{build_conn() | query_params: %{"preview" => nil, "vid" => "latest"}}

      refute class_name(conn) =~ "no-js cms-preview"
    end
  end
end
