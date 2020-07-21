defmodule SiteWeb.TripPlanView do
  @moduledoc "Contains the logic for the Trip Planner"
  use SiteWeb, :view
  require Routes.Route
  alias Fares.{Fare, Format}
  alias Phoenix.{HTML, HTML.Form}
  alias Routes.Route
  alias Site.React
  alias Site.TripPlan.{ItineraryRow, Query}
  alias SiteWeb.PartialView.SvgIconWithCircle
  alias TripPlan.{Itinerary, Leg, Transfer}

  import Schedules.Repo, only: [end_of_rating: 0]

  @meters_per_mile 1609.34

  @type fare_type :: :highest_one_way_fare | :lowest_one_way_fare | :reduced_one_way_fare

  @type fare_calculation :: %{
          mode: Route.gtfs_route_type(),
          # e.g. :commuter_rail
          mode_name: String.t(),
          # e.g. "Commuter Rail"
          name: String.t(),
          # e.g. "Zone 8"
          fares: %Fares.Fare{}
        }

  @spec itinerary_explanation(Query.t(), map) :: iodata
  def itinerary_explanation(%Query{time: :unknown}, _) do
    []
  end

  def itinerary_explanation(%Query{} = q, modes) do
    [
      trip_explanation(q),
      " shown are based on your selections (",
      selected_modes_string(modes),
      ") and closest ",
      time_explanation(q),
      " to ",
      dt_explanation(q),
      "."
    ]
  end

  defp trip_explanation(%{wheelchair_accessible?: false}) do
    "Trips"
  end

  defp trip_explanation(%{wheelchair_accessible?: true}) do
    "Wheelchair accessible trips"
  end

  @spec selected_modes_string(map) :: String.t()
  def selected_modes_string(%{subway: true, commuter_rail: true, bus: true, ferry: true}) do
    "all modes"
  end

  def selected_modes_string(%{} = modes) do
    modes
    |> Enum.filter(fn {_, selected?} -> selected? end)
    |> Enum.map(fn {key, _} -> key |> mode_name() |> String.downcase() end)
    |> Enum.join(", ")
  end

  defp time_explanation(%{time: {:arrive_by, _dt}}) do
    "arrival"
  end

  defp time_explanation(%{time: {:depart_at, _dt}}) do
    "departure"
  end

  defp dt_explanation(%{time: {_type, dt}}) do
    [
      Timex.format!(dt, "{h12}:{m} {AM}, {WDfull}, {Mfull} "),
      Inflex.ordinalize(dt.day)
    ]
  end

  @doc """
  Fetches value to show in input field, preferring to use the geocoded
  Query value if one is available.
  """
  @spec get_input_value(Query.t() | nil, map, :to | :from) :: TripPlan.NamedPosition.t()
  def get_input_value(%Query{} = query, params, field) do
    case Map.get(query, field) do
      pos = %TripPlan.NamedPosition{} ->
        pos

      {:error, _} ->
        get_input_value(nil, params, field)
    end
  end

  def get_input_value(nil, params, field) do
    %TripPlan.NamedPosition{
      name: Map.get(params, Atom.to_string(field))
    }
  end

  def too_future_error do
    end_date = end_of_rating()

    [
      "We can only provide trip data for the current schedule, valid between now and ",
      Timex.format!(end_date, "{M}/{D}/{YY}"),
      "."
    ]
  end

  def past_error do
    ["Date is in the past. " | too_future_error()]
  end

  @plan_errors %{
    outside_bounds: "We can only plan trips inside the MBTA transitshed.",
    no_transit_times: "We were unable to plan a trip at the time you selected.",
    same_address: "You must enter two different locations.",
    location_not_accessible: "We were unable to plan an accessible trip between those locations.",
    path_not_found: "We were unable to plan a trip between those locations.",
    too_close: "We were unable to plan a trip between those locations.",
    unknown: "An unknown error occurred. Please try again, or try a different address.",
    past: &__MODULE__.past_error/0,
    too_future: &__MODULE__.too_future_error/0
  }

  @field_errors %{
    required: "This field is required.",
    no_results: "We're sorry, but we couldn't find that address.",
    invalid_date: "Date is not valid."
  }

  # used by tests
  def plan_errors do
    Map.keys(@plan_errors)
  end

  # used by tests
  def field_errors do
    Map.keys(@field_errors)
  end

  @spec show_plan_error?([atom]) :: boolean
  def show_plan_error?(errors) do
    Enum.any?(errors, &Map.has_key?(@plan_errors, &1))
  end

  @spec plan_error_title([atom]) :: String.t()
  defp plan_error_title([:path_not_found]) do
    "No trips available"
  end

  defp plan_error_title([:too_future]) do
    "Date is too far in the future"
  end

  defp plan_error_title(_) do
    "Unable to plan your trip"
  end

  @spec plan_error_description([atom]) :: Phoenix.HTML.Safe.t()
  def plan_error_description([error]) do
    case Map.get(@plan_errors, error) do
      <<text::binary>> -> text
      too_future_fn when is_function(too_future_fn) -> too_future_fn.()
    end
  end

  def plan_error_description(_) do
    "We were unable to plan your trip. Please try again."
  end

  @spec rendered_location_error(Plug.Conn.t(), Query.t() | nil, :from | :to) ::
          Phoenix.HTML.Safe.t()
  def rendered_location_error(conn, query_or_nil, location_field)

  def rendered_location_error(_conn, nil, _location_field) do
    ""
  end

  def rendered_location_error(%Plug.Conn{} = conn, %Query{} = query, field)
      when field in [:from, :to] do
    case Map.get(query, field) do
      {:error, error} ->
        do_render_location_error(conn, field, error)

      _ ->
        ""
    end
  end

  @spec do_render_location_error(Plug.Conn.t(), :from | :to, TripPlan.Geocode.error()) ::
          Phoenix.HTML.Safe.t()
  defp do_render_location_error(conn, field, {:multiple_results, results}) do
    render("_error_multiple_results.html", conn: conn, field: field, results: results)
  end

  defp do_render_location_error(_conn, _field, atom) when is_atom(atom) do
    Map.get(@field_errors, atom, "")
  end

  @spec date_error([atom]) :: Phoenix.HTML.Safe.t()
  def date_error(errors) do
    if Enum.member?(errors, :invalid_date) do
      {:ok, error_text} = Map.fetch(@field_errors, :invalid_date)
      content_tag(:span, error_text)
    else
      ""
    end
  end

  def mode_class(%ItineraryRow{route: %Route{} = route}), do: route_to_class(route)
  def mode_class(_), do: "personal-itinerary"

  @spec stop_departure_display(ItineraryRow.t()) :: {:render, String.t()} | :blank
  def stop_departure_display(itinerary_row) do
    if itinerary_row.trip do
      :blank
    else
      {:render, format_schedule_time(itinerary_row.departure)}
    end
  end

  @spec render_stop_departure_display(:blank | {:render, String.t()}) :: Phoenix.HTML.Safe.t()
  def render_stop_departure_display(:blank), do: nil

  def render_stop_departure_display({:render, formatted_time}) do
    content_tag(:div, formatted_time, class: "pull-right")
  end

  def bubble_params(%ItineraryRow{transit?: true} = itinerary_row, _row_idx) do
    base_params = %Site.StopBubble.Params{
      route_id: ItineraryRow.route_id(itinerary_row),
      route_type: ItineraryRow.route_type(itinerary_row),
      render_type: :stop,
      bubble_branch: ItineraryRow.route_name(itinerary_row)
    }

    params =
      itinerary_row.steps
      |> Enum.map(fn step ->
        {step, [base_params]}
      end)

    [{:transfer, [%{base_params | class: "stop transfer"}]} | params]
  end

  def bubble_params(%ItineraryRow{transit?: false} = itinerary_row, row_idx) do
    params =
      itinerary_row.steps
      |> Enum.map(fn step ->
        {step,
         [
           %Site.StopBubble.Params{
             render_type: :empty,
             class: "line"
           }
         ]}
      end)

    transfer_bubble_type =
      if row_idx == 0 do
        :terminus
      else
        :stop
      end

    [
      {:transfer,
       [
         %Site.StopBubble.Params{
           render_type: transfer_bubble_type,
           class: [Atom.to_string(transfer_bubble_type), " transfer"]
         }
       ]}
      | params
    ]
  end

  def render_steps(conn, steps, mode_class, itinerary_id, row_id) do
    for {step, bubbles} <- steps do
      render(
        "_itinerary_row_step.html",
        step: step.description,
        alerts: step.alerts,
        stop_id: step.stop_id,
        itinerary_idx: itinerary_id,
        row_idx: row_id,
        mode_class: mode_class,
        bubble_params: bubbles,
        conn: conn
      )
    end
  end

  @spec display_meters_as_miles(float) :: String.t()
  def display_meters_as_miles(meters) do
    :erlang.float_to_binary(meters / @meters_per_mile, decimals: 1)
  end

  def format_additional_route(%Route{id: "Green" <> _branch} = route, direction_id) do
    [
      format_green_line_name(route.name),
      " ",
      Route.direction_name(route, direction_id),
      " towards ",
      GreenLine.naive_headsign(route.id, direction_id)
    ]
  end

  defp format_green_line_name("Green Line " <> branch), do: "Green Line (#{branch})"

  @spec accessibility_icon(TripPlan.Itinerary.t()) :: Phoenix.HTML.Safe.t()
  defp accessibility_icon(%TripPlan.Itinerary{accessible?: accessible?}) do
    content_tag(
      :span,
      [
        svg_icon_with_circle(%SvgIconWithCircle{
          icon:
            if accessible? do
              :access
            else
              :no_access
            end,
          size: :small,
          show_tooltip?: false,
          aria_hidden?: true
        }),
        if accessible? do
          "Accessible"
        else
          "May not be accessible"
        end
      ],
      class: "m-trip-plan-results__itinerary-accessibility"
    )
  end

  @spec icon_for_routes([Route.t()]) :: [Phoenix.HTML.Safe.t()]
  def icon_for_routes(routes), do: Enum.map(routes, &icon_for_route/1)

  @spec icon_for_route(Route.t()) :: Phoenix.HTML.Safe.t()
  def icon_for_route(%Route{description: :rail_replacement_bus}) do
    svg_icon_with_circle(%SvgIconWithCircle{icon: :bus})
  end

  def icon_for_route(%Route{type: 3} = route) do
    SiteWeb.ViewHelpers.bus_icon_pill(route)
  end

  def icon_for_route(route) do
    svg_icon_with_circle(%SvgIconWithCircle{icon: route})
  end

  def datetime_from_query(%Query{time: {:error, _}}), do: datetime_from_query(nil)
  def datetime_from_query(%Query{time: {_depart_or_arrive, dt}}), do: dt
  def datetime_from_query(nil), do: Util.now() |> Site.TripPlan.DateTime.round_minute()

  @spec format_plan_type_for_title(Query.t() | nil) :: Phoenix.HTML.Safe.t()
  def format_plan_type_for_title(%{time: {:arrive_by, dt}}) do
    ["Arrive by ", Timex.format!(dt, "{h12}:{m} {AM}, {M}/{D}/{YY}")]
  end

  def format_plan_type_for_title(%{time: {:depart_at, dt}}) do
    ["Depart at ", Timex.format!(dt, "{h12}:{m} {AM}, {M}/{D}/{YY}")]
  end

  def format_plan_type_for_title(%{time: {:error, _}}) do
    format_plan_type_for_title(nil)
  end

  def format_plan_type_for_title(nil) do
    time = Site.TripPlan.DateTime.round_minute(Util.now())
    ["Depart at ", Timex.format!(time, "{h12}:{m} {AM}, {M}/{D}/{YY}")]
  end

  @spec format_minutes_duration(integer) :: String.t()
  def format_minutes_duration(duration) do
    case duration do
      duration when duration >= 60 ->
        "#{div(duration, 60)} hr #{rem(duration, 60)} min"

      _ ->
        "#{duration} min"
    end
  end

  def trip_plan_datetime_select(form, %DateTime{} = datetime) do
    time_options = [
      hour: [options: 1..12, selected: Timex.format!(datetime, "{h12}")],
      minute: [selected: datetime.minute]
    ]

    date_options = [
      year: [options: Range.new(datetime.year, datetime.year + 1), selected: datetime.year],
      month: [selected: datetime.month],
      day: [selected: datetime.day],
      default: datetime
    ]

    content_tag(
      :div,
      [
        custom_time_select(form, datetime, time_options),
        custom_date_select(form, datetime, date_options)
      ],
      class: "form-group plan-date-time"
    )
  end

  @spec custom_date_select(Form.t(), DateTime.t(), Keyword.t()) :: Phoenix.HTML.Safe.t()
  defp custom_date_select(form, %DateTime{} = datetime, options) do
    min_date = Timex.format!(Util.now(), "{0M}/{0D}/{YYYY}")
    max_date = Timex.format!(end_of_rating(), "{0M}/{0D}/{YYYY}")
    current_date = Timex.format!(datetime, "{WDfull}, {Mfull} {D}, {YYYY}")
    aria_label = "#{current_date}, click or press the enter or space key to edit the date"

    content_tag(
      :div,
      [
        content_tag(
          :label,
          content_tag(
            :div,
            svg_icon_with_circle(%SvgIconWithCircle{icon: :calendar, show_tooltip?: false}),
            class: "m-trip-plan__calendar-input-icon",
            aria_hidden: "true"
          ),
          id: "plan-date-label",
          class: "m-trip-plan__calendar-input-label",
          for: "plan-date-input",
          name: "Date",
          aria_label: aria_label
        ),
        content_tag(
          :input,
          [],
          type: "text",
          class: "plan-date-input",
          id: "plan-date-input",
          data: ["min-date": min_date, "max-date": max_date]
        ),
        date_select(
          form,
          :date_time,
          Keyword.put(options, :builder, &custom_date_select_builder/1)
        )
      ],
      class: "plan-date",
      id: "plan-date"
    )
  end

  @spec custom_date_select_builder(fun) :: Phoenix.HTML.Safe.t()
  defp custom_date_select_builder(field) do
    content_tag(
      :div,
      [
        content_tag(:label, "Month", for: "plan_date_time_month", class: "sr-only"),
        field.(:month, class: "c-select"),
        content_tag(:label, "Day", for: "plan_date_time_day", class: "sr-only"),
        field.(:day, class: "c-select"),
        content_tag(:label, "Year", for: "plan_date_time_year", class: "sr-only"),
        field.(:year, class: "c-select")
      ],
      class: "plan-date-select hidden-js",
      id: "plan-date-select"
    )
  end

  @spec custom_time_select(Form.t(), DateTime.t(), Keyword.t()) :: Phoenix.HTML.Safe.t()
  defp custom_time_select(form, datetime, options) do
    current_time = Timex.format!(datetime, "{h12}:{m} {AM}")
    aria_label = "#{current_time}, click or press the enter or space key to edit the time"

    content_tag(
      :div,
      [
        content_tag(
          :label,
          [],
          id: "plan-time-label",
          class: "m-trip-plan__time-input-label",
          for: "plan-time-input",
          name: "Time",
          aria_label: aria_label,
          data: [time: current_time]
        ),
        time_select(
          form,
          :date_time,
          Keyword.put(options, :builder, &custom_time_select_builder(&1, datetime))
        )
      ],
      class: "plan-time",
      id: "plan-time"
    )
  end

  @minute_options 0..55
                  |> Enum.filter(&(Integer.mod(&1, 5) == 0))
                  |> Enum.map(fn
                    int when int < 10 -> "0" <> Integer.to_string(int)
                    int -> Integer.to_string(int)
                  end)

  defp custom_time_select_builder(field, datetime) do
    content_tag(
      :div,
      [
        content_tag(:label, "Hour", for: "plan_date_time_hour", class: "sr-only"),
        field.(:hour, class: "c-select"),
        content_tag(:label, "Minute", for: "plan_date_time_minute", class: "sr-only"),
        field.(:minute, class: "c-select", options: @minute_options),
        " ",
        content_tag(:label, "AM or PM", for: "plan_date_time_am_pm", class: "sr-only"),
        select(
          :date_time,
          :am_pm,
          [AM: "AM", PM: "PM"],
          selected: Timex.format!(datetime, "{AM}"),
          name: "plan[date_time][am_pm]",
          id: "plan_date_time_am_pm",
          class: "c-select plan-date-time-am-pm"
        )
      ],
      class: "plan-time-select",
      id: "plan-time-select"
    )
  end

  @spec transfer_route_name(Route.t()) :: String.t()
  def transfer_route_name(%Route{type: type} = route) when type in [0, 1] do
    route
    |> Route.to_naive()
    |> Map.get(:name)
  end

  def transfer_route_name(%Route{type: type}) do
    SiteWeb.ViewHelpers.mode_name(type)
  end

  @doc "Add a transfer note to the trip plan view when the itinerary might have valid transit transfers (determined by Transfer.is_maybe_transfer?) that are not already accounted for in the fare calculation. Right now the only transfer accounted for in the calculated fare is subway-subway (via Transfer.is_subway_transfer?)"
  @spec transfer_note(Itinerary.t()) :: String.t() | nil
  def transfer_note(itinerary) do
    itinerary.legs
    |> Stream.filter(&Leg.transit?/1)
    |> Stream.chunk_every(2, 1)
    |> Enum.reject(&Transfer.is_subway_transfer?/1)
    |> Enum.find(&Transfer.is_maybe_transfer?/1)
    |> transfer_note_text
  end

  defp transfer_note_text(nil), do: nil

  defp transfer_note_text(_) do
    HTML.Tag.content_tag(
      :span,
      [
        "Total may be less with ",
        HTML.Tag.content_tag(:a, "transfers", href: "https://www.mbta.com/fares/transfers")
      ]
    )
  end

  def render_to_string(template, data) do
    template |> render(data) |> HTML.safe_to_string()
  end

  def itinerary_map({map_data, map_src}) do
    map_data
    |> Map.put(:tile_server_url, Application.fetch_env!(:site, :tile_server_url))
    |> Map.put(:src, map_src)
  end

  @spec itinerary_html(any, %{conn: atom | %{assigns: atom | map}, expanded: any}) :: [any]
  def itinerary_html(itineraries, %{conn: conn, expanded: expanded}) do
    for {i, routes, map, links, itinerary_row_list, index} <-
          Enum.zip([
            itineraries,
            conn.assigns.routes,
            conn.assigns.itinerary_maps,
            conn.assigns.related_links,
            conn.assigns.itinerary_row_lists,
            Stream.iterate(1, &(&1 + 1))
          ]) do
      tab_html =
        "_itinerary_tab.html"
        |> render_to_string(
          itinerary: i,
          index: index,
          routes: routes,
          itinerary_row_list: itinerary_row_list
        )

      access_html = i |> accessibility_icon() |> HTML.safe_to_string()

      one_way_total_fare = get_one_way_total_by_type(i, :highest_one_way_fare)

      show_monthly_passes? = show_monthly_passes?(i)

      fares_estimate_html =
        "_itinerary_fares.html"
        |> render_to_string(
          itinerary: i,
          one_way_total: Format.price(one_way_total_fare),
          round_trip_total: Format.price(one_way_total_fare * 2),
          show_monthly_passes?: show_monthly_passes?
        )

      fares = get_calculated_fares(i)

      fare_calculator_html =
        "_fare_calculator.html"
        |> render_to_string(
          itinerary: i,
          fares: fares,
          conn: conn,
          show_monthly_passes?: show_monthly_passes?
        )

      html =
        "_itinerary.html"
        |> render_to_string(
          itinerary: i,
          index: index,
          routes: routes,
          links: links,
          itinerary_row_list: itinerary_row_list,
          conn: conn,
          expanded: expanded
        )

      %{
        html: html,
        tab_html: tab_html,
        id: index,
        map: itinerary_map(map),
        access_html: access_html,
        fares_estimate_html: fares_estimate_html,
        fare_calculator_html: fare_calculator_html
      }
    end
  end

  @spec render_react(map) :: HTML.safe()
  def render_react(assigns) do
    Util.log_duration(__MODULE__, :do_render_react, [assigns])
  end

  @spec do_render_react(map) :: HTML.safe()
  def do_render_react(%{
        itineraryData: data
      }) do
    React.render(
      "TripPlannerResults",
      %{
        itineraryData: data
      }
    )
  end

  @spec get_one_way_total_by_type(TripPlan.Itinerary.t(), fare_type) :: non_neg_integer
  def get_one_way_total_by_type(itinerary, fare_type) do
    transit_legs =
      itinerary.legs
      |> Stream.filter(&Leg.transit?/1)
      |> Stream.filter(fn leg -> get_fare_by_type(leg, fare_type) != nil end)

    transit_legs
    |> Stream.with_index()
    |> Enum.reduce(0, fn {leg, leg_index}, acc ->
      if leg_index < 1 do
        acc + (leg |> get_fare_by_type(fare_type) |> fare_cents())
      else
        # Look at this transit leg and previous transit leg
        legs = transit_legs |> Enum.slice(leg_index - 1, 2)

        # If this is part of a free transfer, don't add fare
        if Transfer.is_subway_transfer?(legs) do
          acc
        else
          acc + (leg |> get_fare_by_type(fare_type) |> fare_cents())
        end
      end
    end)
  end

  @spec fare_cents(Fare.t() | nil) :: non_neg_integer()
  defp fare_cents(nil), do: 0
  defp fare_cents(%Fare{cents: cents}), do: cents

  @spec monthly_pass(Fare.t() | nil) :: String.t()
  def monthly_pass(nil), do: "#{Format.full_name(nil)}: None"

  def monthly_pass(fare) do
    "#{cr_prefix(fare)}#{Format.concise_full_name(fare)}: #{Format.price(fare)}"
  end

  @spec cr_prefix(Fare.t()) :: String.t()
  defp cr_prefix(%Fare{mode: :commuter_rail}), do: "Commuter Rail "
  defp cr_prefix(_), do: ""

  @spec get_calculated_fares(TripPlan.Itinerary.t()) :: %{mode: fare_calculation}
  def get_calculated_fares(itinerary) do
    itinerary.legs
    |> Enum.filter(fn leg -> Leg.transit?(leg) end)
    |> Enum.filter(fn leg ->
      get_fare_by_type(leg, :highest_one_way_fare) != nil
    end)
    |> Enum.reduce(%{}, fn leg, acc ->
      highest_fare =
        leg
        |> get_fare_by_type(:highest_one_way_fare)

      mode =
        highest_fare
        |> Kernel.get_in([Access.key(:mode)])

      mode_key =
        if is_tuple(highest_fare.name) do
          mode_detail = Enum.join(Tuple.to_list(highest_fare.name))
          String.to_atom(Atom.to_string(mode) <> "_" <> mode_detail)
        else
          mode
        end

      if Map.has_key?(acc, mode_key) do
        acc
      else
        name =
          if leg.name && leg.name =~ "Shuttle",
            do: "Shuttle",
            else: Format.name(highest_fare.name)

        Map.put(acc, mode_key, %{
          mode: %{
            mode: mode,
            mode_name: mode_name(mode),
            name: name,
            fares: %{
              highest_one_way_fare: highest_fare,
              lowest_one_way_fare:
                leg
                |> get_fare_by_type(:lowest_one_way_fare),
              reduced_one_way_fare:
                leg
                |> get_fare_by_type(:reduced_one_way_fare)
            }
          }
        })
      end
    end)
  end

  @spec get_fare_by_type(TripPlan.Leg.t(), fare_type) :: Fares.Fare.t()
  def get_fare_by_type(leg, fare_type) do
    leg
    |> Kernel.get_in([
      Access.key(:mode, %{}),
      Access.key(:fares, %{}),
      Access.key(fare_type)
    ])
  end

  @spec filter_media(Fare.t()) :: [Fare.media()] | Fare.media()
  # For CR there are some fare surcharges if payment is made in cash on board.
  # So for this particular case, cash is filtered out:
  def filter_media(%Fare{mode: :commuter_rail} = fare) do
    fare
    |> Kernel.get_in([Access.key(:media)])
    |> Enum.filter(fn media -> media != :cash end)
  end

  def filter_media(fare), do: fare |> Kernel.get_in([Access.key(:media)])

  @spec format_media([Fare.media()] | Fare.media()) :: iodata
  def format_media(:mticket), do: "mTicket"

  def format_media(list) when is_list(list) do
    list
    |> Enum.map(&format_media/1)
    |> Util.AndOr.join(:or)
  end

  def format_media(media), do: Format.media(media)

  @spec format_mode(fare_calculation) :: String.t()
  def format_mode(mode_values) do
    case mode_values.mode do
      :bus -> "#{mode_values.name}"
      :commuter_rail -> "#{mode_values.mode_name} #{mode_values.name}"
      _ -> "#{mode_values.mode_name}"
    end
  end

  # Hide monthly pass sections in the case of a Silver Line trip with no transfers from Logain Airport.
  # Public solely for testing.
  @spec show_monthly_passes?(Itinerary.t()) :: boolean()
  def show_monthly_passes?(itinerary), do: !sl_only_trip_from_airport?(itinerary)

  @spec sl_only_trip_from_airport?(Itinerary.t()) :: boolean()
  defp sl_only_trip_from_airport?(itinerary) do
    transit_legs = Itinerary.transit_legs(itinerary)
    first_leg = List.first(transit_legs)
    route_id = first_leg.mode.route_id
    from_stop_id = first_leg.from.stop_id

    length(transit_legs) == 1 && Fares.silver_line_airport_stop?(route_id, from_stop_id)
  end
end
