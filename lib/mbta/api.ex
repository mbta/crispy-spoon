defmodule MBTA.Api do
  @moduledoc """
  Handles fetching and caching generic JSON:API responses from the MBTA API.
  """

  require Logger

  use HTTPoison.Base

  alias MBTA.SentryExtra
  alias Util

  @behaviour MBTA.Api.Behaviour

  @default_timeout Application.compile_env!(:dotcom, :v3_api_default_timeout)
  @httpoison Application.compile_env!(:dotcom, :httpoison)
  @http_pool Application.compile_env!(:dotcom, :v3_api_http_pool)

  @impl MBTA.Api.Behaviour
  def get_json(url, params \\ [], opts \\ []) do
    _ =
      Logger.debug(fn ->
        "MBTA.Api.get_json url=#{url} params=#{params |> Map.new() |> Poison.encode!()}"
      end)

    body = ""
    opts = Keyword.merge(default_options(), opts)

    with {time, response} <- timed_get(url, params, opts),
         :ok <- log_response(url, params, time, response),
         {:ok, http_response} <- response,
         {:ok, body} <- body(http_response) do
      body
      |> JsonApi.parse()
      |> maybe_log_parse_error(url, params, body)
    else
      {:error, error} ->
        _ = log_response_error(url, params, body)
        {:error, error}

      error ->
        _ = log_response_error(url, params, body)
        {:error, error}
    end
  end

  defp timed_get(url, params, opts) do
    api_key = Keyword.fetch!(opts, :api_key)
    base_url = Keyword.fetch!(opts, :base_url)

    headers =
      MBTA.Headers.build(
        api_key,
        params: params,
        url: url,
        use_cache?: true
      )

    url = base_url <> URI.encode(url)
    timeout = Keyword.fetch!(opts, :timeout)

    {time, response} =
      :timer.tc(fn ->
        @httpoison.get(url, headers,
          params: params,
          timeout: timeout,
          recv_timeout: timeout,
          hackney: [pool: @http_pool]
        )
      end)

    {time, response}
  end

  @spec maybe_log_parse_error(JsonApi.t() | {:error, any}, String.t(), Keyword.t(), String.t()) ::
          JsonApi.t() | {:error, any}
  defp maybe_log_parse_error({:error, error}, url, params, body) do
    _ = log_response_error(url, params, body)
    {:error, error}
  end

  defp maybe_log_parse_error(response, _, _, _) do
    response
  end

  @spec log_response(String.t(), Keyword.t(), integer, any) :: :ok
  defp log_response(url, params, time, response) do
    entry = fn ->
      "MBTA.Api.get_json_response url=#{inspect(url)} " <>
        "params=#{params |> Map.new() |> Poison.encode!()} " <>
        log_body(response) <>
        " duration=#{time / 1000}" <>
        " request_id=#{Logger.metadata() |> Keyword.get(:request_id)}"
    end

    _ = SentryExtra.log_context("api-response", entry)
    _ = Logger.info(entry)
    :ok
  end

  @spec log_response_error(String.t(), Keyword.t(), String.t()) :: :ok
  defp log_response_error(url, params, body) do
    entry = fn ->
      "MBTA.Api.get_json_response url=#{inspect(url)} " <>
        "params=#{params |> Map.new() |> Poison.encode!()} response=" <> body
    end

    _ = SentryExtra.log_context("api-response-error", entry)
    _ = Logger.info(entry)
    :ok
  end

  defp log_body({:ok, response}) do
    "status=#{response.status_code} content_length=#{byte_size(response.body)}"
  end

  defp log_body({:error, error}) do
    ~s(status=error error="#{inspect(error)}")
  end

  def body(%{headers: headers, body: body}) do
    case Enum.find(
           headers,
           &(String.downcase(elem(&1, 0)) == "content-encoding")
         ) do
      {_, "gzip"} ->
        {:ok, :zlib.gunzip(body)}

      _ ->
        {:ok, body}
    end
  rescue
    e in ErlangError -> {:error, e.original}
  end

  def body(other) do
    other
  end

  @impl HTTPoison.Base
  def process_request_headers(headers) do
    [
      {"accept-encoding", "gzip"},
      {"accept", "application/vnd.api+json"}
      | headers
    ]
  end

  defp default_options do
    [
      base_url: config(:v3_api_base_url),
      api_key: config(:v3_api_key),
      timeout: @default_timeout
    ]
  end

  defp config(key) do
    Util.config(:dotcom, key)
  end
end
