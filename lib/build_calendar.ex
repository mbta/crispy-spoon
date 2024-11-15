defmodule BuildCalendar do
  @type url :: String.t()

  defmodule Calendar do
    @moduledoc """

    Represents a calendar for display.

    * previous_month_url: either a URL to get to the previous month, or nil if we shouldn't link to it
    * next_month_url: a URL to get to the next month, or nil if we shouldn't link to it
    * days: a list of BuildCalendar.Day structs, representing each day we're displaying for the calendar
    """
    @type t :: %__MODULE__{
            previous_month_url: String.t() | nil,
            next_month_url: String.t() | nil,
            active_date: Date.t(),
            days: [BuildCalendar.Day.t()],
            holidays: [Holiday.t()],
            upcoming_holidays: [Holiday.t()]
          }
    defstruct previous_month_url: nil,
              next_month_url: nil,
              active_date: nil,
              days: [],
              holidays: [],
              upcoming_holidays: []

    @doc "Breaks the days of a Calendar into 1-week chunks."
    def weeks(%Calendar{days: days}) do
      Enum.chunk_every(days, 7)
    end
  end

  defmodule Day do
    @moduledoc """

    Represents a single day displayed for a Calendar.

    * date: the full date
    * month_relation: how this date relates to the month of the Calendar
    * selected?: true if the Day represents the currently selected date
    * holiday?: true if the Day is a holiday
    * url: a URL to set this Day as the selected one
    """

    import PhoenixHTMLHelpers.Tag
    import PhoenixHTMLHelpers.Link

    @type month_relation :: :current | :previous | :next
    @type t :: %__MODULE__{
            date: Date.t(),
            month_relation: month_relation,
            selected?: boolean,
            holiday?: boolean,
            url: BuildCalendar.url(),
            today?: boolean
          }

    defstruct date: ~D[0000-01-01],
              month_relation: :current,
              selected?: false,
              holiday?: false,
              url: nil,
              today?: false

    @spec td(t) :: Phoenix.HTML.Safe.t()
    def td(%Day{month_relation: :previous} = day) do
      content_tag(:td, "", class: class(day))
    end

    def td(%Day{date: date, url: url} = day) do
      formatted_date = Timex.format!(date, "{WDfull}, {Mfull} {D}")

      content_tag :td, class: class(day) do
        link("#{date.day}", to: url, title: formatted_date, "aria-label": formatted_date)
      end
    end

    def class(day) do
      # The list is a tuple of {boolean, class_name}.  We filter out the
      # false booleans, then get the class names and join them.
      classes =
        [
          {Timex.weekday(day.date) > 5, "schedule-weekend"},
          {day.holiday?, "schedule-holiday"},
          {day.selected? && day.month_relation == :current, "schedule-selected"},
          {day.month_relation == :next, "schedule-next-month"},
          {day.today?, "schedule-today"}
        ]
        |> Enum.filter(&match?({true, _}, &1))
        |> Enum.map(&elem(&1, 1))

      Enum.join(classes, " ")
    end
  end

  @typedoc "A function which, given some keyword arguments, returns a URL.  Used for building URLs to select dates."
  @type url_fn :: (Keyword.t() -> url)

  @doc """
  Builds the links that will be displayed on the calendar.

  Options:
  * shift: an number of months forward or backwards to shift the selected day when building the calendar
  * end_date: a date after which we shouldn't link to future months
  """
  @spec build(Date.t(), Date.t(), [Holiday.t()], url_fn, Keyword.t()) ::
          BuildCalendar.Calendar.t()
  def build(selected, today, holidays, url_fn, opts \\ []) do
    holiday_set = MapSet.new(holidays, & &1.date)
    end_date = opts[:end_date]
    shift = opts[:shift] || 0

    %BuildCalendar.Calendar{
      previous_month_url: previous_month_url(selected, today, shift, url_fn),
      next_month_url: next_month_url(selected, end_date, shift, url_fn),
      active_date: Timex.shift(selected, months: shift),
      days: build_days(selected, today, shift, holiday_set, url_fn),
      holidays: holidays,
      upcoming_holidays:
        Enum.drop_while(holidays, fn holiday -> Date.compare(holiday.date, today) == :lt end)
    }
  end

  @spec previous_month_url(Date.t(), Date.t(), integer, url_fn) :: String.t() | nil
  defp previous_month_url(selected, today, shift, url_fn) do
    shifted = Timex.shift(selected, months: shift)

    if {shifted.month, shifted.year} == {today.month, today.year} do
      nil
    else
      url_fn.(shift: shift - 1)
    end
  end

  @spec next_month_url(Date.t(), Date.t() | nil, integer, url_fn) :: String.t() | nil
  defp next_month_url(_selected, nil, shift, url_fn) do
    url_fn.(shift: shift + 1)
  end

  defp next_month_url(selected, end_date, shift, url_fn) do
    next_month =
      selected
      |> Timex.shift(months: shift + 1)
      |> Timex.beginning_of_month()

    if Date.compare(next_month, end_date) == :gt do
      nil
    else
      next_month_url(selected, nil, shift, url_fn)
    end
  end

  @spec build_days(Date.t(), Date.t(), integer, MapSet.t(), url_fn) :: [BuildCalendar.Day.t()]
  defp build_days(selected, today, shift, holiday_set, url_fn) do
    shifted = Timex.shift(selected, months: shift)

    last_day_of_previous_month =
      shifted
      |> Timex.beginning_of_month()
      |> Timex.shift(days: -1)

    last_day_of_this_month = Timex.end_of_month(shifted)

    for date <- Date.range(first_day(shifted), last_day(shifted)) do
      %BuildCalendar.Day{
        date: date,
        url: build_url(url_fn, date, today),
        month_relation: month_relation(date, last_day_of_previous_month, last_day_of_this_month),
        selected?: date == selected,
        holiday?: MapSet.member?(holiday_set, date),
        today?: date == today
      }
    end
  end

  @spec first_day(Date.t()) :: Date.t()
  defp first_day(date) do
    date
    |> Timex.beginning_of_month()
    # Sunday
    |> Timex.beginning_of_week(7)
  end

  @spec last_day(Date.t()) :: Date.t()
  defp last_day(date) do
    # at the last day of the month, add a week, then go the end of the
    # current week.  We use Sunday as the end of the week.
    date
    |> Timex.end_of_month()
    |> Timex.shift(days: 7)
    |> Timex.end_of_week(7)
  end

  @spec build_url(url_fn, Date.t(), Date.t()) :: String.t()
  defp build_url(url_fn, today, today) do
    url_fn.(date: nil, date_select: nil, shift: nil)
  end

  defp build_url(url_fn, date, _) do
    url_fn.(date: Date.to_iso8601(date), date_select: nil, shift: nil)
  end

  @spec month_relation(Date.t(), Date.t(), Date.t()) :: __MODULE__.Day.month_relation()
  defp month_relation(date, last_day_of_previous_month, last_day_of_this_month) do
    cond do
      Date.compare(date, last_day_of_this_month) == :gt ->
        :next

      Date.compare(date, last_day_of_previous_month) == :gt ->
        :current

      true ->
        :previous
    end
  end
end
