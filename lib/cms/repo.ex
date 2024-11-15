defmodule CMS.Repo do
  @moduledoc """
  Interface for the content CMS.
  Returns a variety of content related structs, like %Event{} or %Basic{}.

  The repo relies heavily on `CMS.Cache` which implements the Nebulex Redis Adapter.
  The cache is set with `@cache Application.compile_env!(:dotcom, :cache)` so that we can easily swap out a local cache during tests.
  The base ttl for the repo is one hour.
  """

  use Nebulex.Caching.Decorators

  require Logger

  import CMS.Helpers, only: [preview_opts: 1]

  alias CMS.Partial.{
    Banner,
    Paragraph,
    RoutePdf,
    Teaser,
    WhatsHappeningItem
  }

  alias CMS.API
  alias CMS.Page
  alias CMS.Page.{Event, NewsEntry}
  alias CMS.Search.Result

  alias Routes.Route

  @cache Application.compile_env!(:dotcom, :cache)
  @cms_api Application.compile_env!(:dotcom, :cms_api_module)
  @ttl :timer.hours(4)

  @spec get_page(String.t(), map) :: Page.t() | {:error, API.error()}
  def get_page(path, query_params \\ %{}) do
    case view_or_preview(path, query_params) do
      {:ok, api_data} -> Page.from_api(api_data, preview_opts(query_params))
      {:error, error} -> {:error, error}
    end
  end

  @spec get_page_with_encoded_id(String.t(), map) ::
          Page.t() | {:error, API.error()}
  def get_page_with_encoded_id(path, %{"id" => _} = query_params) do
    {id, params} = Map.pop(query_params, "id")
    encoded_id = URI.encode_www_form("?id=#{id}")

    path
    |> Kernel.<>(encoded_id)
    |> get_page(params)
  end

  @spec news_entry_by(Keyword.t()) :: NewsEntry.t() | :not_found
  def news_entry_by(opts) do
    case do_news_entry_by(opts) do
      [record | _] -> record
      [] -> :not_found
    end
  end

  @decorate cacheable(
              cache: @cache,
              on_error: :nothing,
              opts: [ttl: 60_000]
            )
  def do_news_entry_by(opts) do
    case @cms_api.view("/cms/news", opts) do
      {:ok, api_data} -> Enum.map(api_data, &NewsEntry.from_api/1)
      _ -> []
    end
  end

  @decorate cacheable(
              cache: @cache,
              key: "cms.repo|events",
              on_error: :nothing,
              opts: [ttl: @ttl]
            )
  def events(opts \\ []) do
    case @cms_api.view("/cms/events", opts) do
      {:ok, api_data} -> Enum.map(api_data, &Event.from_api/1)
      _ -> []
    end
  end

  @spec event(integer) :: Event.t() | :not_found
  def event(id) do
    case events(id: id) do
      [record] -> record
      _ -> :not_found
    end
  end

  @spec event_by(Keyword.t()) :: Event.t() | :not_found
  def event_by(opts) do
    case events(opts) do
      [record] -> record
      [] -> :not_found
    end
  end

  @decorate cacheable(
              cache: @cache,
              key: "cms.repo|whats-happening",
              on_error: :nothing,
              opts: [ttl: @ttl]
            )
  def whats_happening do
    case @cms_api.view("/cms/whats-happening", []) do
      {:ok, api_data} -> Enum.map(api_data, &WhatsHappeningItem.from_api/1)
      _ -> []
    end
  end

  @spec banner() :: Banner.t() | nil
  def banner do
    cached_value = do_banner()

    if cached_value == :empty || cached_value == :error, do: nil, else: cached_value
  end

  @decorate cacheable(
              cache: @cache,
              key: "cms.repo|important-notices",
              on_error: :nothing,
              opts: [ttl: @ttl]
            )
  def do_banner do
    case @cms_api.view("/cms/important-notices", []) do
      {:ok, [api_data | _]} -> Banner.from_api(api_data)
      {:ok, _} -> :empty
      {:error, _} -> :error
    end
  end

  @spec search(String.t(), integer, [String.t()]) :: any
  def search(query, offset, content_types) do
    params = [q: query, page: offset] ++ Enum.map(content_types, &{:"type[]", &1})

    with {:ok, api_data} <- @cms_api.view("/cms/search", params) do
      {:ok, Result.from_api(api_data)}
    end
  end

  @spec get_schedule_pdfs(Route.id_t()) :: [RoutePdf.t()]
  def get_schedule_pdfs(route_id) do
    case do_get_schedule_pdfs(route_id) do
      {:ok, pdfs} ->
        pdfs

      error ->
        _ =
          Logger.warning(fn ->
            "module=#{__MODULE__} Error getting schedule pdfs for route #{route_id}. Using default []. Error: #{inspect(error)}"
          end)

        []
    end
  end

  @decorate cacheable(
              cache: @cache,
              key: "cms.repo|schedules|#{String.downcase(route_id)}",
              on_error: :nothing,
              opts: [ttl: @ttl]
            )
  defp do_get_schedule_pdfs(route_id) do
    case @cms_api.view("/cms/schedules/#{route_id}", []) do
      {:ok, pdfs} ->
        {:ok, Enum.map(pdfs, &RoutePdf.from_api/1)}

      error ->
        error
    end
  end

  @spec get_route_pdfs(Route.id_t()) :: [RoutePdf.t()]
  def get_route_pdfs(route_id) do
    case do_get_route_pdfs(route_id) do
      {:ok, pdfs} ->
        pdfs

      error ->
        _ =
          Logger.warning(fn ->
            "Error getting pdfs for route #{route_id}. Using default []. Error: #{inspect(error)}"
          end)

        []
    end
  end

  @decorate cacheable(
              cache: @cache,
              key: "cms.repo|route-pdfs|#{String.downcase(route_id)}",
              on_error: :nothing,
              opts: [ttl: @ttl]
            )
  defp do_get_route_pdfs(route_id) do
    case @cms_api.view("/cms/route-pdfs/#{route_id}", []) do
      {:ok, []} ->
        {:ok, []}

      {:ok, [api_data | _]} ->
        pdfs =
          api_data
          |> Map.get("field_pdfs")
          |> Enum.map(&RoutePdf.from_api/1)

        {:ok, pdfs}

      error ->
        error
    end
  end

  # BEGIN PAGE CACHING #

  @behaviour Nebulex.Caching.KeyGenerator

  @impl true
  def generate(_, _, [path, %Plug.Conn.Unfetched{aspect: :query_params}]) do
    key = path |> String.trim("/") |> String.replace(~r/\//, "|")

    "cms.repo|#{key}"
  end

  def generate(_, _, [path, params]) do
    key = path |> String.trim("/") |> String.replace(~r/\//, "|")

    "cms.repo|#{key}" <> params_to_string(params)
  end

  defp params_to_string(params) when params == %{}, do: ""
  defp params_to_string(params) when is_binary(params), do: params

  defp params_to_string(params) when is_map(params) do
    case params
         |> Enum.reduce([], &CMS.Api.stringify_params/2)
         |> Enum.map(fn {k, v} -> "#{k}=#{v}" end) do
      [head | tail] ->
        ["?#{head}", "#{Enum.join(tail, "&")}"]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("&")

      _ ->
        ""
    end
  end

  defp params_to_string(_), do: ""

  @spec view_or_preview(String.t(), map) :: {:ok, map} | {:error, API.error()}
  defp view_or_preview(path, %{"preview" => _, "vid" => "latest"} = params) do
    # "preview" value is deprecated. Use empty string or nil to get latest revision.
    view_or_preview(path, Map.put(params, "vid", nil))
  end

  defp view_or_preview(_path, %{"preview" => _, "vid" => vid, "nid" => node_id}) do
    case Integer.parse(node_id) do
      {nid, ""} ->
        nid
        |> @cms_api.preview(vid)
        |> handle_revision()

      _ ->
        # Invalid or missing node ID
        {:error, :not_found}
    end
  end

  @decorate cacheable(
              cache: @cache,
              key_generator: __MODULE__,
              on_error: :nothing,
              opts: [ttl: @ttl]
            )
  defp view_or_preview(path, params) do
    @cms_api.view(path, params)
  end

  # END PAGE CACHING #

  @spec handle_revision({:error, any} | {:ok, [map]}) :: {:error, String.t()} | {:ok, map}
  defp handle_revision({:error, err}), do: {:error, err}

  defp handle_revision({:ok, []}), do: {:error, :not_found}

  defp handle_revision({:ok, revisions}) when is_list(revisions), do: {:ok, List.first(revisions)}

  @doc """
  Returns a list of teaser items. Documentation can be found at
  https://github.com/mbta/cms/blob/master/API.md#teasers

  TYPE

  Opts can include :type, which is a list that can contain one
  or more of the API.type() atoms (ex: [:news_entry, :event]).
  Elixir formats this list into a CMS-compatible URL parameter.

  If no types are specified, results can be of mixed types.

  To filter by a route include :route_id, for example:
    "/guides/subway" or just "subway"

  SORTING

  If neither :sort_order nor :sort_by are provided, Elixir will
  attempt to fill-in these values according to content :type.
  Otherwise, the values provided will be used and passed on.

  :sort_by is set automatically when :type requires it.
  :sort_order is DESC by default; only used with :sort_by.
  """

  @type teaser_filters :: %{
          optional(:sidebar) => 0 | 1,
          optional(:type) => [API.type()],
          optional(:type_op) => String.t(),
          optional(:related_to) => integer,
          optional(:except) => integer,
          optional(:only) => integer,
          optional(:items_per_page) => 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 20 | 50,
          optional(:date_op) => String.t(),
          optional(:date) => [value: String.t()] | [min: String.t(), max: String.t()],
          optional(:sort_order) => :DESC | :ASC,
          optional(:sort_by) => String.t()
        }

  @spec teasers(Keyword.t()) :: [Teaser.t()]
  def teasers(opts \\ []) when is_list(opts) do
    opts
    |> teaser_path()
    |> @cms_api.view(teaser_params(opts))
    |> do_teasers(opts)
  end

  @spec teaser_path(Keyword.t()) :: String.t()
  defp teaser_path(opts) do
    path =
      case Enum.into(opts, %{}) do
        %{route_id: route_id, topic: topic} -> "/#{topic}/#{route_id}"
        %{mode: mode, topic: topic} -> "/#{topic}/#{mode}"
        %{topic: topic} -> "/#{topic}/any"
        %{mode: mode} -> "/any/#{mode}"
        %{route_id: route_id} -> "/any/#{route_id}"
        %{args: args} -> "/" <> Enum.join(args, "/")
        _ -> nil
      end

    "/cms/teasers#{path}"
  end

  @spec teaser_params(Keyword.t()) :: teaser_filters
  defp teaser_params(opts) do
    opts
    |> Map.new()
    |> teaser_sort()
  end

  @spec teaser_sort(teaser_filters) :: teaser_filters
  defp teaser_sort(%{sort_by: _, sort_order: _} = params) do
    params
  end

  defp teaser_sort(%{type: [type]} = params)
       when type in [:news_entry, :event, :project_update, :project] do
    order = Map.get(params, :sort_order, :DESC)

    field =
      case type do
        type when type in [:project_update, :news_entry] -> "field_posted_on_value"
        :project -> "field_updated_on_value"
        :event -> "field_start_time_value"
      end

    Map.merge(params, %{sort_by: field, sort_order: order})
  end

  defp teaser_sort(params) do
    Map.drop(params, [:sort_order, :sort_by])
  end

  @spec do_teasers({:ok, [map]} | {:error, any}, Keyword.t()) :: [Teaser.t()]
  defp do_teasers({:ok, teasers}, _) do
    Enum.map(teasers, &Teaser.from_api/1)
  end

  defp do_teasers({:error, error}, opts) do
    _ =
      [
        "module=#{__MODULE__}",
        "method=teasers",
        "error=" <> inspect(error),
        "opts=#{inspect(opts)}"
      ]
      |> Enum.join(" ")
      |> Logger.warning()

    []
  end

  @doc """
  Paragraphs are stand-alone partials from the CMS. Supports redirects.
  """
  @spec get_paragraph(String.t(), map) :: Paragraph.t() | {:error, any()}
  def get_paragraph(path, query_params \\ %{}) do
    case view_or_preview(path, query_params) do
      {:ok, api_data} ->
        Paragraph.from_api(api_data, preview_opts(query_params))

      {:error, {:redirect, _status, to: new_path}} ->
        get_paragraph(new_path, query_params)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc "Get all the events, paginating through results if needed, and caches the result"
  @spec events_for_year(Calendar.year()) :: [Teaser.t()]
  def events_for_year(year) do
    do_events_for_range(
      min: Timex.beginning_of_year(year) |> Util.convert_to_iso_format(),
      max: Timex.end_of_year(year) |> Timex.shift(days: 1) |> Util.convert_to_iso_format()
    )
  end

  @spec do_events_for_range([min: String.t(), max: String.t()], non_neg_integer(), [Teaser.t()]) ::
          [Teaser.t()]
  @decorate cacheable(cache: @cache, on_error: :nothing, opts: [ttl: 60_000])
  defp do_events_for_range(range, offset \\ 0, all_events \\ []) do
    per_page = 50

    opts = [
      type: [:event],
      items_per_page: per_page,
      date_op: "between",
      date: range,
      offset: offset * per_page,
      sort_order: :ASC
    ]

    case teasers(opts) do
      [] ->
        all_events

      more_events ->
        total_events = all_events ++ more_events

        if Kernel.length(more_events) == per_page do
          do_events_for_range(range, offset + 1, total_events)
        else
          total_events
        end
    end
  end

  @doc "Get the next n events"
  def next_n_event_teasers(start_date, n) when n >= 0 do
    single = [
      value: Util.convert_to_iso_format(start_date)
    ]

    opts = [
      type: [:event],
      items_per_page: n,
      date_op: ">=",
      date: single,
      sort_order: :ASC
    ]

    teasers(opts)
  end

  def next_n_event_teasers(_, _), do: []
end
