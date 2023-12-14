defmodule Algolia.ApiTest do
  use ExUnit.Case, async: false

  @failure_response ~s({"error": "bad request"})
  @request ~s({"requests": [{"indexName": "*"}]})
  @success_response ~s({"ok": "success"})

  describe "action" do
    setup do
      ConCache.ets(Algolia.Api) |> :ets.delete_all_objects()
      {:ok, bypass: Bypass.open(), failure: Bypass.open(), success: Bypass.open()}
    end

    test "caches a successful response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/1/indexes/*/queries", fn conn ->
        Plug.Conn.send_resp(conn, 200, @success_response)
      end)

      opts = %Algolia.Api{
        host: "http://localhost:#{bypass.port}",
        index: "*",
        action: "queries",
        body: @request
      }

      assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
               Algolia.Api.action(:post, opts)

      assert body == @success_response
      # Can be called again with result from cache instead of hitting the API endpoint
      assert {:ok, %HTTPoison.Response{status_code: 200, body: ^body}} =
               Algolia.Api.action(:post, opts)
    end

    test "sends a get request to /1/indexes/$INDEX", %{bypass: bypass} do
      # bypass = Bypass.open()

      Bypass.expect_once(bypass, "GET", "/1/indexes/*", fn conn ->
        Plug.Conn.send_resp(conn, 200, "{\"hits\": [{\"objectID\": \"test_object_id\"}]}")
      end)

      opts = %Algolia.Api{
        host: "http://localhost:#{bypass.port}",
        index: "*",
        action: "",
        body: ""
      }

      assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
               Algolia.Api.action(:get, opts)

      assert body == "{\"hits\": [{\"objectID\": \"test_object_id\"}]}"
    end

    test "does not cache a failed response", %{failure: failure, success: success} do
      Bypass.expect_once(failure, "POST", "/1/indexes/*/queries", fn conn ->
        Plug.Conn.send_resp(conn, 400, @failure_response)
      end)

      failure_opts = %Algolia.Api{
        host: "http://localhost:#{failure.port}",
        index: "*",
        action: "queries",
        body: @request
      }

      assert {:error, %HTTPoison.Response{status_code: 400, body: body}} =
               Algolia.Api.action(:post, failure_opts)

      assert body == @failure_response

      Bypass.expect_once(success, "POST", "/1/indexes/*/queries", fn conn ->
        Plug.Conn.send_resp(conn, 200, @success_response)
      end)

      success_opts = %Algolia.Api{
        host: "http://localhost:#{success.port}",
        index: "*",
        action: "queries",
        body: @request
      }

      assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
               Algolia.Api.action(:post, success_opts)

      assert body == @success_response
    end

    test "adds the query params to the request url", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/1/indexes/test_index/", fn conn ->
        assert "param_1=test_data" == conn.query_string
        Plug.Conn.send_resp(conn, 200, "{\"hits\": [{\"objectID\": \"test_object_id\"}]}")
      end)

      opts = %Algolia.Api{
        host: "http://localhost:#{bypass.port}",
        index: "test_index",
        action: "",
        body: "",
        query_params: %{param_1: "test_data"}
      }

      assert {:ok, %HTTPoison.Response{status_code: 200, body: body}} =
               Algolia.Api.action(:get, opts)

      assert body == "{\"hits\": [{\"objectID\": \"test_object_id\"}]}"
    end

    test "logs a warning if config keys are missing", %{bypass: bypass} do
      opts = %Algolia.Api{
        host: "http://localhost:#{bypass.port}",
        index: "*",
        action: "queries",
        body: @request
      }

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert Algolia.Api.action(:post, opts, %Algolia.Config{}) == {:error, :bad_config}
        end)

      assert log =~ "missing Algolia config keys"
    end
  end
end
