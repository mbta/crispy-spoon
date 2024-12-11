defmodule DotcomWeb.Components.TripPlanner.ItineraryDetail do
  @moduledoc """
  The section of the trip planner page that shows the map and
  the summary or details panel
  """

  use DotcomWeb, :component

  import DotcomWeb.Components.TripPlanner.Place
  import DotcomWeb.Components.TripPlanner.TransitLeg, only: [transit_leg: 1]
  import DotcomWeb.Components.TripPlanner.WalkingLeg, only: [walking_leg: 1]

  alias Alerts.Match
  alias Dotcom.TripPlan.{Alerts, PersonalDetail, TransitDetail}

  def itinerary_detail(
        %{
          itineraries: itineraries,
          selected_itinerary_detail_index: selected_itinerary_detail_index
        } = assigns
      ) do
    assigns =
      assign(assigns, :selected_itinerary, Enum.at(itineraries, selected_itinerary_detail_index))

    ~H"""
    <div>
      <.depart_at_buttons
        selected_itinerary_detail_index={@selected_itinerary_detail_index}
        itineraries={@itineraries}
      />
      <.specific_itinerary_detail itinerary={@selected_itinerary} />
    </div>
    """
  end

  attr :itineraries, :list
  attr :selected_itinerary_detail_index, :integer

  defp depart_at_buttons(assigns) do
    ~H"""
    <div :if={Enum.count(@itineraries) > 1}>
      <p class="text-sm mb-2 mt-3">Depart at</p>
      <div id="itinerary-detail-departure-times" class="flex flex-wrap gap-2">
        <.depart_at_button
          :for={{itinerary, index} <- Enum.with_index(@itineraries)}
          active={@selected_itinerary_detail_index == index}
          phx-click="set_itinerary_index"
          phx-value-trip-index={index}
        >
          {Timex.format!(itinerary.start, "%-I:%M%p", :strftime)}
        </.depart_at_button>
      </div>
    </div>
    """
  end

  attr :active, :boolean
  attr :rest, :global
  slot :inner_block

  defp depart_at_button(%{active: active} = assigns) do
    background_class = if active, do: "bg-brand-primary-lightest", else: "bg-transparent"
    assigns = assign(assigns, :background_class, background_class)

    ~H"""
    <button
      type="button"
      class={[
        "border border-brand-primary rounded px-2.5 py-1.5 text-brand-primary text-lg",
        "hover:bg-brand-primary-lightest #{@background_class}"
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp specific_itinerary_detail(assigns) do
    assigns =
      assigns
      |> assign_new(:alerts, fn -> Alerts.from_itinerary(assigns.itinerary) end)
      |> assign(:start_place, List.first(assigns.itinerary.legs).from)
      |> assign(:start_time, List.first(assigns.itinerary.legs).start)
      |> assign(:end_place, List.last(assigns.itinerary.legs).to)
      |> assign(:end_time, List.last(assigns.itinerary.legs).stop)

    ~H"""
    <div class="mt-4">
      <.place place={@start_place} time={@start_time} />
      <div
        :for={leg <- @itinerary.legs}
        class={"#{if(match?(%TransitDetail{}, leg.mode), do: "bg-gray-bordered-background")}"}
      >
        <%= if match?(%PersonalDetail{}, leg.mode) do %>
          <.walking_leg leg={leg} />
        <% else %>
          <.transit_leg leg={leg} alerts={alerts_for_leg(@alerts, leg)} />
        <% end %>
      </div>
      <.place place={@end_place} time={@end_time} />
    </div>
    """
  end

  defp alerts_for_leg(alerts, leg) when is_list(alerts) do
    Match.match(
      alerts,
      Alerts.leg_entities(leg),
      leg.start
    )
  end

  defp alerts_for_leg(_, _), do: []
end
