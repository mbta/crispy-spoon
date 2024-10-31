defmodule DotcomWeb.Live.TripPlanner do
  @moduledoc """
  The entire Trip Planner experience, including submitting and validating user
  input, querying and parsing results from OpenTripPlanner, and rendering the
  results in a list and map format.
  """

  use DotcomWeb, :live_view

  alias DotcomWeb.Components.LiveComponents.TripPlannerForm
  alias Dotcom.TripPlan.{InputForm.Modes, ItineraryGroups}

  import DotcomWeb.Components.TripPlanner.ItineraryGroup, only: [itinerary_group: 1]
  import MbtaMetro.Components.{Feedback, Spinner}

  @form_id "trip-planner-form"

  @map_config Application.compile_env!(:mbta_metro, :map)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:error, nil)
      |> assign(:form_name, @form_id)
      |> assign(:map_config, @map_config)
      |> assign(:pins, [])
      |> assign(:submitted_values, nil)
      |> assign_async(:groups, fn ->
        {:ok, %{groups: nil}}
      end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Trip Planner <mark style="font-weight: 400">Preview</mark></h1>
    <div style="row">
      <.live_component module={TripPlannerForm} id={@form_name} form_name={@form_name} />
      <section :if={@submitted_values} class="mt-2 mb-6">
        <p class="text-lg font-semibold mb-0"><%= submission_summary(@submitted_values) %></p>
        <p><%= time_summary(@submitted_values) %></p>
        <.async_result :let={groups} assign={@groups}>
          <:failed :let={{:error, reason}}>
            <.feedback kind={:error}>
              <%= Phoenix.Naming.humanize(reason) %>
            </.feedback>
          </:failed>
          <:loading>
            <.spinner aria_label="Waiting for results" /> Waiting for results...
          </:loading>
          <%= if groups do %>
            <%= if Enum.count(groups) == 0 do %>
              <.feedback kind={:warning}>No trips found.</.feedback>
            <% else %>
              <.feedback kind={:success}>
                Found <%= Enum.count(groups) %> <%= Inflex.inflect("way", Enum.count(groups)) %> to go.
              </.feedback>
            <% end %>
          <% end %>
        </.async_result>
      </section>
      <section class="flex w-full border border-solid border-slate-400">
        <div :if={@error} class="w-full p-4 text-rose-400">
          <%= inspect(@error) %>
        </div>
        <.async_result :let={groups} assign={@groups}>
          <div :if={groups} class="w-full p-4">
            <.itinerary_group :for={group <- groups} group={group} />
          </div>
        </.async_result>
        <.live_component
          module={MbtaMetro.Live.Map}
          id="trip-planner-map"
          class="h-96 w-full relative overflow-none"
          config={@map_config}
          pins={@pins}
        />
      </section>
    </div>
    """
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:changed_form, params}, socket) do
    new_socket =
      socket
      |> update_from_pin(params)
      |> update_to_pin(params)

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:updated_form, %Dotcom.TripPlan.InputForm{} = data}, socket) do
    socket =
      socket
      |> assign(:submitted_values, data)
      |> assign(:groups, nil)
      |> assign_async(:groups, fn ->
        case Dotcom.TripPlan.OpenTripPlanner.plan(data) do
          {:ok, itineraries} ->
            Process.sleep(1200)
            {:ok, %{groups: ItineraryGroups.from_itineraries(itineraries)}}

          error ->
            error
        end
      end)

    {:noreply, socket}
  end

  def handle_info(_info, socket) do
    {:noreply, socket}
  end

  defp update_from_pin(socket, %{
         "from" => %{"longitude" => from_longitude, "latitude" => from_latitude}
       }) do
    update_pin_in_socket(socket, [from_longitude, from_latitude], 0)
  end

  defp update_to_pin(socket, %{"to" => %{"longitude" => to_longitude, "latitude" => to_latitude}}) do
    update_pin_in_socket(socket, [to_longitude, to_latitude], 1)
  end

  defp update_pin_in_socket(socket, [longitude, latitude], index)
       when longitude != "" and latitude != "" do
    pins =
      place_pin(
        socket.assigns.pins,
        [String.to_float(longitude), String.to_float(latitude)],
        index
      )

    socket |> assign(:pins, pins)
  end

  defp update_pin_in_socket(socket, [longitude, latitude], index)
       when longitude == "" or latitude == "" do
    pins = remove_pin(socket.assigns.pins, index)

    socket |> assign(:pins, pins)
  end

  defp update_pin_in_socket(socket, _coordinates, _index) do
    socket
  end

  defp place_pin([], pin, 0) do
    [pin]
  end

  defp place_pin([], pin, 1) do
    [[], pin]
  end

  defp place_pin(pins, pin, 0) do
    [pin | List.delete_at(pins, 0)]
  end

  defp place_pin(pins, pin, 1) do
    [List.first(pins) | [pin]]
  end

  defp place_pin(pins, _pin, _index) do
    pins
  end

  defp remove_pin([], _index), do: []

  defp remove_pin(pins, 0) do
    [[] | List.delete_at(pins, 0)]
  end

  defp remove_pin(pins, 1) do
    [List.first(pins)]
  end

  defp remove_pin(pins, _index) do
    pins
  end

  defp submission_summary(%{from: %{name: from_name}, to: %{name: to_name}, modes: modes}) do
    "Planning trips from #{from_name} to #{to_name} using #{Modes.selected_modes(modes)}"
  end

  defp time_summary(%{datetime_type: datetime_type, datetime: datetime}) do
    preamble = if datetime_type == :arrive_by, do: "Arriving by ", else: "Leaving at "
    time_description = Timex.format!(datetime, "{h12}:{m}{am}")
    date_description = Timex.format!(datetime, "{WDfull}, {Mfull} {D}")
    preamble <> time_description <> " on " <> date_description
  end
end
