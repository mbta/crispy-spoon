defmodule Util do
  @moduledoc "Utilities module"

  use Timex

  require Logger

  {:ok, endpoint} = Application.compile_env(:dotcom, :util_endpoint)
  {:ok, route_helper_module} = Application.compile_env(:dotcom, :util_router_helper_module)

  @endpoint endpoint
  @route_helper_module route_helper_module
  @local_tz "America/New_York"

  @doc "The current datetime in the America/New_York timezone."
  @spec now() :: DateTime.t()
  @spec now((String.t() -> DateTime.t())) :: DateTime.t()
  def now(utc_now_fn \\ &Timex.now/1) do
    @local_tz
    |> utc_now_fn.()
    |> to_local_time()

    # to_local_time(utc_now_fn.())
  end

  def date_as_js_string(%DateTime{} = date_time) do
    Timex.format!(date_time, "%FT%H:%M", :strftime)
  end

  def date_as_js_string(%Date{} = date) do
    Timex.format!(date, "%FT%H:%M", :strftime)
  end

  def date_as_js_string(%NaiveDateTime{} = naive_date_time) do
    Timex.format!(naive_date_time, "%FT%H:%M", :strftime)
  end

  @doc "Today's date in the America/New_York timezone."
  def today do
    now() |> Timex.to_date()
  end

  @spec time_is_greater_or_equal?(
          DateTime.t() | NaiveDateTime.t(),
          DateTime.t() | NaiveDateTime.t()
        ) :: boolean
  def time_is_greater_or_equal?(time, ref_time) do
    compare_fn =
      case {time, ref_time} do
        {%DateTime{}, %DateTime{}} ->
          &DateTime.compare/2

        {%NaiveDateTime{}, %NaiveDateTime{}} ->
          &NaiveDateTime.compare/2
      end

    case compare_fn.(time, ref_time) do
      :gt -> true
      :eq -> true
      :lt -> false
    end
  end

  def parse_date_time(%DateTime{} = date_time) do
    date_time
  end

  def parse_date_time(%NaiveDateTime{} = date_time) do
    date_time
  end

  def parse_date_time(string) when is_binary(string) do
    Timex.parse!(string, "{YYYY}-{M}-{D} {_h24}:{_m} {AM}")
  end

  def parse_date_time(map) when is_map(map) do
    case parse(map) do
      {:error, _} ->
        Timex.now()

      date_time ->
        date_time
    end
  end

  def parse_date_time(_), do: Timex.now()

  @spec parse(map | DateTime.t()) :: NaiveDateTime.t() | DateTime.t() | {:error, :invalid_date}
  def parse(date_params) do
    case date_to_string(date_params) do
      <<str::binary>> ->
        str
        |> Timex.parse("{YYYY}-{M}-{D} {_h24}:{_m} {AM}")
        |> do_parse()

      error ->
        error
    end
  end

  defp do_parse({:ok, %NaiveDateTime{} = naive}) do
    if Timex.is_valid?(naive) do
      naive
    else
      {:error, :invalid_date}
    end
  end

  defp do_parse({:error, _}), do: {:error, :invalid_date}

  @spec date_to_string(map | DateTime.t()) :: String.t() | DateTime.t() | {:error, :invalid_date}
  defp date_to_string(%{
         "year" => year,
         "month" => month,
         "day" => day,
         "hour" => hour,
         "minute" => minute,
         "am_pm" => am_pm
       }) do
    "#{year}-#{month}-#{day} #{hour}:#{minute} #{am_pm}"
  end

  defp date_to_string(date) when is_binary(date), do: date

  defp date_to_string(%DateTime{} = date) do
    date
  end

  defp date_to_string(%{}) do
    {:error, :invalid_date}
  end

  @spec date_to_naive_date(NaiveDateTime.t() | DateTime.t() | Date.t()) :: NaiveDateTime.t()
  def date_to_naive_date(%Date{} = date), do: NaiveDateTime.new(date, ~T[00:00:00.00]) |> elem(1)
  def date_to_naive_date(%DateTime{} = date), do: DateTime.to_naive(date)
  def date_to_naive_date(%NaiveDateTime{} = date), do: date

  def convert_to_iso_format(date) do
    date
    |> Timex.format!("{ISOdate}")
  end

  @doc "Gives the date for tomorrow based on the provided date"
  def tomorrow_date(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.add(1)
    |> Date.to_string()
  end

  @doc "Converts a NaiveDateTime to a DateTime with the given time zone, handling ambiguities. Defaults to America/New_York if errors"
  @spec convert_using_timezone(NaiveDateTime.t(), String.t()) :: DateTime.t()
  def convert_using_timezone(time, time_zone) do
    tz =
      if Timex.Timezone.exists?(time_zone) do
        time_zone
      else
        "America/New_York"
      end

    time
    |> Timex.Timezone.convert(tz)
    |> handle_ambiguous_time()
  end

  @doc "Converts a DateTime.t into the America/New_York zone, handling ambiguities"
  @spec to_local_time(DateTime.t() | NaiveDateTime.t() | Timex.AmbiguousDateTime.t()) ::
          DateTime.t() | {:error, any}
  def to_local_time(%DateTime{zone_abbr: zone} = time)
      when zone in ["EDT", "EST", "-04", "-05"] do
    time
  end

  def to_local_time(%DateTime{zone_abbr: "UTC"} = time) do
    time
    |> Timex.Timezone.convert(@local_tz)
    |> handle_ambiguous_time()
  end

  # important: assumes the NaiveDateTime is in UTC.
  def to_local_time(%NaiveDateTime{} = time) do
    time
    |> DateTime.from_naive!("Etc/UTC")
    |> to_local_time()
  end

  def to_local_time(%Timex.AmbiguousDateTime{} = time), do: handle_ambiguous_time(time)

  @spec handle_ambiguous_time(Timex.AmbiguousDateTime.t() | DateTime.t() | {:error, any}) ::
          DateTime.t() | {:error, any}
  defp handle_ambiguous_time(%Timex.AmbiguousDateTime{after: aft}) do
    # ambiguous time only happens between midnight and 3am
    # during November daylight saving transition
    aft
  end

  defp handle_ambiguous_time(%DateTime{} = time) do
    time
  end

  defp handle_ambiguous_time({:error, error}) do
    {:error, error}
  end

  def local_tz, do: @local_tz

  @doc """
  Converts an {:error, _} tuple to a default value.

  # Examples

    iex> Util.error_default(:value, :default)
    :value
    iex> Util.error_default({:error, :tuple}, :default)
    :default
  """
  @spec error_default(value | {:error, any}, value) :: value
        when value: any
  def error_default(error_or_default, default)

  def error_default({:error, _}, default) do
    default
  end

  def error_default(value, _default) do
    value
  end

  @doc """

  The current service date.  The service date lasts from 3am to 2:59am, so
  times after midnight belong to the service of the previous date.

  """
  @spec service_date(DateTime.t() | NaiveDateTime.t()) :: Date.t()
  def service_date(current_time \\ Util.now()) do
    current_time
    |> to_local_time()
    |> do_service_date()
  end

  defp do_service_date(%DateTime{hour: hour} = time) when hour < 3 do
    time
    |> Timex.shift(hours: -3)
    |> DateTime.to_date()
  end

  defp do_service_date(%DateTime{} = time) do
    DateTime.to_date(time)
  end

  @doc """

  Returns an id property in a struct or nil

  """
  def safe_id(%{id: id}), do: id
  def safe_id(nil), do: nil

  @doc "Interleaves two lists. Appends the remaining elements of the longer list"
  @spec interleave(list, list) :: list
  def interleave([h1 | t1], [h2 | t2]), do: [h1, h2 | interleave(t1, t2)]
  def interleave([], l), do: l
  def interleave(l, []), do: l

  @doc """
  Calls all the functions asynchronously, and returns a list of results.
  If a function times out, its result will be the provided default.
  """
  @spec async_with_timeout([(-> any)], any, atom, non_neg_integer, non_neg_integer) :: [any]
  def async_with_timeout(functions, default, module, timeout \\ 5000, retries \\ 0)
      when is_list(functions) and is_atom(module) do
    functions
    |> Enum.map(&Task.async/1)
    |> Task.yield_many(timeout)
    |> Enum.with_index()
    |> Enum.map(&task_result_or_default_loop(&1, default, module, retries))
  end

  # If a number of retries was specified, then go through those retries before settling on
  # the default value.
  defp task_result_or_default_loop({{task, result}, index}, default, module, retries) do
    if retries > 0 do
      case task_result_or_default(result, default, task, module, index) do
        x when x == default ->
          task_result_or_default_loop({{task, result}, index}, default, module, retries - 1)

        any ->
          any
      end
    else
      task_result_or_default(result, default, task, module, index)
    end
  end

  @doc """
  Yields the value from a task, or returns a default value.
  """
  @spec yield_or_default(Task.t(), non_neg_integer, any, atom) :: any
  def yield_or_default(%Task{} = task, timeout, default, module) when is_atom(module) do
    task
    |> Task.yield(timeout)
    |> task_result_or_default(default, task, module, "")
  end

  @doc """
  Takes a map of tasks and calls &Task.yield_many/2 on them, then rebuilds the map with
  either the result of the task, or the default if the task times out or exits early.
  """
  @type task_map :: %{optional(Task.t()) => {atom, any}}
  @spec yield_or_default_many(task_map, atom, non_neg_integer) :: map
  def yield_or_default_many(%{} = task_map, module, timeout \\ 5000) when is_atom(module) do
    task_map
    |> Map.keys()
    |> Task.yield_many(timeout)
    |> Map.new(&do_yield_or_default_many(&1, task_map, module))
  end

  @spec do_yield_or_default_many({Task.t(), {:ok, any} | {:exit, term} | nil}, task_map, atom) ::
          {atom, any}
  defp do_yield_or_default_many({%Task{} = task, result}, task_map, module) do
    {key, default} = Map.get(task_map, task)
    {key, task_result_or_default(result, default, task, module, key)}
  end

  @spec task_result_or_default({:ok, any} | {:exit, term} | nil, any, Task.t(), atom, any) :: any
  defp task_result_or_default({:ok, result}, _default, _task, _module, _key) do
    result
  end

  defp task_result_or_default({:exit, reason}, default, _task, module, key) do
    _ =
      Logger.warning(
        "module=#{module} " <>
          "key=#{key} " <>
          "error=async_error " <>
          "error_type=timeout " <>
          "Async task exited for reason: #{inspect(reason)} -- Defaulting to: #{inspect(default)}"
      )

    default
  end

  defp task_result_or_default(nil, default, %Task{} = task, module, key) do
    case Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      _ ->
        _ =
          Logger.warning(
            "module=#{module} " <>
              "key=#{key} " <>
              "error=async_error " <>
              "error_type=timeout " <>
              "Async task timed out -- Defaulting to: #{inspect(default)}"
          )

        default
    end
  end

  @doc """
  Makes DotcomWeb.Router.Helpers available to other apps.
  #
  # Examples

    iex> Util.site_path(:schedule_path, [:show, "test"])
    "/schedules/test"
  """
  @spec site_path(atom, [any]) :: String.t()
  def site_path(helper_fn, opts) when is_list(opts) do
    apply(@route_helper_module, helper_fn, [@endpoint | opts])
  end

  @doc """
  Fetches config values, handling system env and default values.
  """
  @spec config(atom, atom, atom) :: any
  def config(app, key, subkey) do
    {:ok, val} =
      app
      |> Application.fetch_env!(key)
      |> Access.fetch(subkey)

    do_config(val)
  end

  @spec config(atom, atom) :: any
  def config(app, key) do
    app
    |> Application.get_env(key)
    |> do_config()
  end

  defp do_config(val) do
    case val do
      {:system, envvar, default} ->
        System.get_env(envvar) || default

      {:system, envvar} ->
        System.get_env(envvar)

      value ->
        value
    end
  end

  @doc """
  Logs how long a function call took.
  """
  @spec log_duration(atom, atom, [any]) :: any
  def log_duration(module, function, args) do
    {time, result} = :timer.tc(module, function, args)
    time = time / :timer.seconds(1)

    _ =
      Logger.info(fn ->
        "module=#{module} function=#{function} duration=#{time}"
      end)

    result
  end
end
