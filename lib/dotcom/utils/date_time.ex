defmodule Dotcom.Utils.DateTime do
  @moduledoc """
  A collection of functions for working with date_times.

  Consuming modules are responsible for parsing or converting date_times.
  They should *always* call `coerce_ambiguous_date_time/1` before using a date_time.
  This is mainly because Timex has so many functions that serve as entry points to date_times.
  Those functions can return ambiguous date_times during DST transitions.
  """

  use Timex

  alias Dotcom.Utils.DateTime.Behaviour

  @behaviour Behaviour

  @typedoc """
  A date_time_range is a tuple of two date_times: {start, stop}.
  Either the start or stop can be nil, but not both.
  """
  @type date_time_range() ::
          {DateTime.t(), DateTime.t()} | {nil, DateTime.t()} | {DateTime.t(), nil}

  @timezone Application.compile_env!(:dotcom, :timezone)

  @doc """
  Get the date_time in the set @timezone.
  """
  @impl Behaviour
  def now(), do: Timex.now(@timezone)

  @doc """
  In the default case, we'll return a DateTime when given one.

  Timex can give us ambiguous times when we "fall-back" in DST transitions.
  That is because the same hour occurs twice.
  In that case, we choose the later time.

  Timex will return an error if the time occurs when we "spring-forward" in DST transitions.
  That is because one hour does not occur--02:00:00am to 03:00:00am.
  In that case, we set the time to 03:00:00am.

  If we are given something tha tis not a DateTime, AmbiguousDateTime, or an error tuple, we log the input and return `now`.
  """
  @impl Behaviour
  def coerce_ambiguous_date_time(%DateTime{} = date_time), do: date_time
  def coerce_ambiguous_date_time(%Timex.AmbiguousDateTime{after: later}), do: later

  def coerce_ambiguous_date_time({:error, {_, @timezone, seconds_from_zeroyear, _}}) do
    Timex.zero()
    |> Timex.shift(seconds: seconds_from_zeroyear)
    |> Timex.to_datetime(@timezone)
    |> coerce_ambiguous_date_time()
    |> Timex.shift(hours: 2)
    |> coerce_ambiguous_date_time()
  end

  @doc """
  Given a date_time_range and a date_time, returns true if the date_time is within the date_time_range.
  """
  @impl Behaviour
  def in_range?({nil, nil}, _), do: false

  def in_range?({nil, %DateTime{} = stop}, %DateTime{} = date_time) do
    Timex.before?(date_time, stop) || Timex.equal?(date_time, stop, :microsecond)
  end

  def in_range?({%DateTime{} = start, nil}, %DateTime{} = date_time) do
    Timex.after?(date_time, start) || Timex.equal?(date_time, start, :microsecond)
  end

  def in_range?({%DateTime{} = start, %DateTime{} = stop}, %DateTime{} = date_time) do
    in_range?({start, nil}, date_time) && in_range?({nil, stop}, date_time)
  end

  def in_range?(_, _), do: false
end
