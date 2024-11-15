defmodule DotcomWeb.Components.TripPlanner.ItineraryGroup do
  @moduledoc """
  A component to render an itinerary group.
  """
  use DotcomWeb, :component

  import DotcomWeb.Components.TripPlanner.ItineraryDetail

  attr(:summary, :map, doc: "ItineraryGroups.summary()", required: true)
  attr(:itineraries, :list, doc: "List of %Dotcom.TripPlan.Itinerary{}", required: true)

  @doc """
  Renders a single itinerary group.
  """
  def itinerary_group(assigns) do
    assigns =
      assign(assigns, :group_id, "group-#{:erlang.phash2(assigns.itineraries)}")

    ~H"""
    <div class="border border-solid m-4 p-4">
      <div
        :if={@summary.tag}
        class="whitespace-nowrap leading-none font-bold font-heading text-sm uppercase bg-brand-primary-darkest text-white px-3 py-2 mb-3 -ml-4 -mt-4 rounded-br-lg w-min"
      >
        <%= @summary.tag %>
      </div>
      <div class="flex flex-row mb-3 font-bold text-lg justify-between">
        <div>
          <%= format_datetime_full(@summary.first_start) %> - <%= format_datetime_full(
            @summary.first_stop
          ) %>
        </div>
        <div>
          <%= @summary.duration %> min
        </div>
      </div>
      <div class="flex flex-wrap gap-1 items-center content-center mb-3">
        <%= for {summary_leg, index} <- Enum.with_index(@summary.summarized_legs) do %>
          <.icon :if={index > 0} name="angle-right" class="font-black w-2" />
          <.leg_icon {summary_leg} />
        <% end %>
      </div>
      <div class="flex flex-wrap gap-1 items-center mb-3 text-sm text-grey-dark">
        <div :if={@summary.accessible?} class="inline-flex items-center gap-0.5">
          <.icon type="icon-svg" name="icon-accessible-small" class="h-3 w-3 mr-0.5" /> Accessible
          <.icon name="circle" class="h-0.5 w-0.5 mx-1" />
        </div>
        <div class="inline-flex items-center gap-0.5">
          <.icon name="person-walking" class="h-3 w-3" />
          <%= @summary.walk_distance %> mi
        </div>
        <div :if={@summary.total_cost > 0} class="inline-flex items-center gap-0.5">
          <.icon name="circle" class="h-0.5 w-0.5 mx-1" />
          <.icon name="wallet" class="h-3 w-3" />
          <%= Fares.Format.price(@summary.total_cost) %>
        </div>
      </div>
      <div class="flex justify-end items-center">
        <div :if={Enum.count(@summary.next_starts) > 0} class="grow text-sm text-grey-dark">
          Similar trips depart at <%= Enum.map(@summary.next_starts, &format_datetime_short/1)
          |> Enum.join(", ") %>
        </div>
        <button class="btn-link font-semibold underline" phx-click={JS.toggle(to: "##{@group_id}")}>
          Details
        </button>
      </div>
      <div id={@group_id} class="mt-30" style="display: none;">
        <.itinerary_detail :for={itinerary <- @itineraries} itinerary={itinerary} />
      </div>
    </div>
    """
  end

  attr(:class, :string, default: "")
  attr(:routes, :list, required: true, doc: "List of %Routes.Route{}")
  attr(:walk_minutes, :integer, required: true)

  # No routes
  defp leg_icon(%{routes: [], walk_minutes: _} = assigns) do
    ~H"""
    <span class={[
      "flex items-center gap-1 text-sm font-semibold leading-none whitespace-nowrap py-1 px-2 rounded-full border border-solid border-gray-light",
      @class
    ]}>
      <.icon name="person-walking" class="h-4 w-4" />
      <span><%= @walk_minutes %> min</span>
    </span>
    """
  end

  # Group of commuter rail routes are summarized to one symbol.
  defp leg_icon(%{routes: [%Routes.Route{type: 2} | _]} = assigns) do
    ~H"""
    <.route_symbol route={List.first(@routes)} class={@class} />
    """
  end

  # No grouping when there's only one route!
  defp leg_icon(%{routes: [%Routes.Route{}]} = assigns) do
    ~H"""
    <.route_symbol route={List.first(@routes)} {assigns} />
    """
  end

  defp leg_icon(
         %{routes: [%Routes.Route{type: type, external_agency_name: agency} | _]} = assigns
       ) do
    slashed? = type == 3 && is_nil(agency)

    assigns =
      assigns
      |> assign(:slashed?, slashed?)
      |> assign(
        :grouped_classes,
        if(slashed?,
          do: "[&:not(:first-child)]:rounded-l-none [&:not(:last-child)]:rounded-r-none !px-3",
          else: "rounded-full ring-white ring-2"
        )
      )

    ~H"""
    <div class="flex items-center -space-x-0.5">
      <%= for {route, index} <- Enum.with_index(@routes) do %>
        <.route_symbol route={route} class={"#{@grouped_classes} #{zindex(index)} #{@class}"} />
        <%= if @slashed? and index < Kernel.length(@routes) - 1 do %>
          <div class={"bg-white -mt-0.5 w-1 h-7 #{zindex(index)} transform rotate-[17deg]"}></div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp leg_icon(assigns) do
    inspect(assigns) |> Sentry.capture_message(tags: %{feature: "Trip Planner"})

    ~H"""
    <span></span>
    """
  end

  defp zindex(index) do
    "z-#{50 - index * 10}"
  end

  defp format_datetime_full(datetime) do
    Timex.format!(datetime, "%-I:%M %p", :strftime)
  end

  defp format_datetime_short(datetime) do
    Timex.format!(datetime, "%-I:%M", :strftime)
  end
end
