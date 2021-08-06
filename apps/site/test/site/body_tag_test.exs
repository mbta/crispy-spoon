defmodule Site.BodyTagTest do
  use ExUnit.Case, async: true
  import Site.BodyTag
  import Phoenix.ConnTest, only: [build_conn: 0]
  import Phoenix.HTML, only: [safe_to_string: 1]
  import Plug.Conn, only: [put_req_header: 3, put_private: 3]

  describe "render/1" do
    test "returns no-js by default" do
      assert safe_to_string(render(build_conn())) =~ "no-js"
    end

    test "returns js if the request came from turbolinks" do
      conn =
        build_conn()
        |> put_req_header("turbolinks-referrer", "referrer")

      assert safe_to_string(render(conn)) =~ "js"
    end

    test "returns js not-found if we get to an error page from turbolinks" do
      conn =
        build_conn()
        |> put_req_header("turbolinks-referrer", "referrer")
        |> put_private(:phoenix_view, SiteWeb.ErrorView)

      assert safe_to_string(render(conn)) =~ "js not-found"
    end

    test "returns mticket if the requisite header is present" do
      conn =
        build_conn()
        |> put_req_header(Application.get_env(:site, Site.BodyTag)[:mticket_header], "")

      assert safe_to_string(render(conn)) =~ "no-js mticket"
    end

    test "returns mticket if the site is called as mticket.mbtace.com" do
      conn = %{build_conn() | host: "mticket.mbtace.com"}

      assert safe_to_string(render(conn)) =~ "no-js mticket"
    end

    test "returns 'cms-preview' if page is loaded with CMS ?preview params" do
      conn = %{build_conn() | query_params: %{"preview" => nil, "vid" => "latest", "nid" => "6"}}

      assert safe_to_string(render(conn)) =~ "no-js cms-preview"
    end

    test "does not set 'cms-preview' class if page is loaded with missing CMS &nid param" do
      conn = %{build_conn() | query_params: %{"preview" => nil, "vid" => "latest"}}

      refute safe_to_string(render(conn)) =~ "no-js cms-preview"
    end

    test "returns 'c-iframe-wrapper' for the /reduced-fares/* path" do
      conn = %{build_conn() | path_info: ["reduced-fares", "youth-pass"]}
      assert safe_to_string(render(conn)) =~ "c-iframe-wrapper"
    end
  end
end
