defmodule Algolia.Api do
  @moduledoc """
  Interact with Algolia via their API.
  """

  use Nebulex.Caching.Decorators

  require Logger

  alias Algolia.Config

  defstruct [:host, :index, :action, :body, :query_params]

  @cache Application.compile_env!(:dotcom, :cache)
  @http_pool Application.compile_env!(:dotcom, :algolia_http_pool)
  @httpoison Application.compile_env!(:dotcom, :httpoison)
  @ttl :timer.hours(12)

  @type action :: :post | :get

  @type t :: %__MODULE__{
          host: String.t() | nil,
          index: String.t() | nil,
          action: String.t() | nil,
          body: String.t() | nil,
          query_params: map | nil
        }

  @spec action(action, t) ::
          {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t() | :bad_config}
  def action(action, opts, config \\ nil)

  def action(action, %__MODULE__{} = opts, nil) do
    action(action, opts, Config.config())
  end

  def action(
        action,
        %__MODULE__{} = opts,
        %Config{write: <<_::binary>>, app_id: <<_::binary>>} = config
      ) do
    do_action(action, opts, config)
  end

  def action(_action, %__MODULE__{}, %Config{} = config) do
    _ = Logger.warning("module=#{__MODULE__} missing Algolia config keys: #{inspect(config)}")
    {:error, :bad_config}
  end

  defp do_action(
         action,
         %__MODULE__{index: index, action: "queries", body: body} = opts,
         %Config{} = config
       )
       when is_binary(index) and is_binary(body) do
    hackney = opts |> hackney_opts() |> Keyword.put(:pool, @http_pool)

    cached_send_post_request({body, config}, action, hackney, opts)
  end

  defp do_action(
         action,
         %__MODULE__{index: index, action: opts_action, body: body} = opts,
         %Config{} = config
       )
       when is_binary(index) and is_binary(opts_action) and is_binary(body) do
    hackney = opts |> hackney_opts() |> Keyword.put(:pool, @http_pool)

    send_post_request({body, config}, action, hackney, opts)
  end

  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: @ttl])
  defp cached_send_post_request({body, config}, action, hackney, opts) do
    send_post_request({body, config}, action, hackney, opts)
  end

  defp send_post_request({body, config}, action, hackney, opts) do
    query_param_string = generate_query_param_string(opts)

    response =
      opts
      |> generate_url(config, query_param_string)
      |> send_request(action, body, config, hackney)

    case response do
      {:ok, %HTTPoison.Response{status_code: 200}} -> response
      {_, invalid_response} -> {:error, invalid_response}
    end
  end

  def send_request(url, :post, body, config, hackney),
    do: @httpoison.post(url, body, headers(config), hackney: hackney)

  def send_request(url, :get, _body, config, hackney),
    do: @httpoison.get(url, headers(config), hackney: hackney)

  @spec generate_query_param_string(t) :: String.t() | nil
  defp generate_query_param_string(%{query_params: nil}), do: nil

  defp generate_query_param_string(%{query_params: query_params}),
    do: URI.encode_query(query_params)

  @spec generate_url(t, Config.t(), String.t() | nil) :: String.t()
  defp generate_url(%__MODULE__{} = opts, %Config{} = config, nil) do
    Path.join([base_url(opts, config), "1", "indexes", opts.index, opts.action])
  end

  defp generate_url(%__MODULE__{} = opts, %Config{} = config, query_param_string) do
    Path.join([
      base_url(opts, config),
      "1",
      "indexes",
      opts.index,
      opts.action <> "?" <> query_param_string
    ])
  end

  defp base_url(%__MODULE__{host: nil}, %Config{app_id: <<app_id::binary>>}) do
    "https://" <> app_id <> "-dsn.algolia.net"
  end

  defp base_url(%__MODULE__{host: "http://localhost:" <> _ = host}, %Config{}) do
    host
  end

  @spec headers(Config.t()) :: [{String.t(), String.t()}]
  defp headers(%Config{} = config) do
    [
      {"X-Algolia-API-Key", config.write},
      {"X-Algolia-Application-Id", config.app_id}
    ]
  end

  defp hackney_opts(%__MODULE__{index: "*"}) do
    # By default, hackney encodes "*"; passing this option skips this encoding
    # see https://github.com/benoitc/hackney/issues/272#issuecomment-174334135
    [path_encode_fun: fn path -> path end]
  end

  defp hackney_opts(%__MODULE__{}) do
    []
  end
end
