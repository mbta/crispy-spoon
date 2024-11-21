defmodule DotcomWeb.Components.LiveComponents.TripPlannerForm do
  @moduledoc """
  A form to plan trips.
  """
  use DotcomWeb, :live_component

  import MbtaMetro.Components.{Feedback, InputGroup}
  import Phoenix.HTML.Form, only: [input_value: 2]

  alias Dotcom.TripPlan.{InputForm, InputForm.Modes}
  alias DotcomWeb.LiveComponents.TripPlannerLocationAutocomplete
  alias MbtaMetro.Live.DatePicker

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  @doc """
  If form values are passed in, we merge them with the defaults and submit the form.

  Otherwise, we just render the form.
  """
  def update(assigns, socket) do
    form_defaults = get_form_defaults(assigns)

    defaults = %{
      form: %InputForm{} |> InputForm.changeset(form_defaults) |> to_form(),
      show_datepicker: false
    }

    new_socket =
      socket
      |> assign(assigns)
      |> assign(defaults)

    if assigns[:form_values] do
      save_form(form_defaults, new_socket)
    end

    {:ok, new_socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="px-10 py-8 lg:px-20 lg:py-12 mb-4 bg-gray-100">
      <.form
        :let={f}
        class="md:grid md:grid-cols-2 gap-x-8 gap-y-2"
        id={@id}
        for={@form}
        method="get"
        phx-submit="save_form"
        phx-change="handle_change"
        phx-target={@myself}
      >
        <div :for={field <- [:from, :to]} class="mb-1" id={"#{@form_name}--#{field}-wrapper"}>
          <.live_component
            id={"#{@form_name}--#{field}"}
            module={TripPlannerLocationAutocomplete}
            field={f[field]}
          />
          <.feedback :for={{msg, _} <- f[field].errors} :if={used_input?(f[field])} kind={:error}>
            <%= msg %>
          </.feedback>
        </div>
        <div>
          <.input_group
            legend="When"
            form={f}
            field={:datetime_type}
            id="datetime_type"
            options={[{"Now", "now"}, {"Leave at", "leave_at"}, {"Arrive by", "arrive_by"}]}
            type="radio-button"
            class="mb-0"
            phx-change="toggle_datepicker"
            phx-update="ignore"
          />
          <.feedback
            :for={{msg, _} <- f[:datetime_type].errors}
            :if={used_input?(f[:datetime_type])}
            kind={:error}
          >
            <%= msg %>
          </.feedback>
          <.live_component
            :if={@show_datepicker}
            module={DatePicker}
            config={datepicker_config()}
            field={f[:datetime]}
            id={:datepicker}
          />
          <.feedback
            :for={{msg, _} <- f[:datetime].errors}
            :if={used_input?(f[:datetime])}
            kind={:error}
          >
            <%= msg %>
          </.feedback>
        </div>
        <div>
          <.fieldset id="modes" legend="Modes">
            <.accordion id="accordion">
              <:heading>
                <%= Modes.selected_modes(input_value(f, :modes)) %>
              </:heading>
              <:content>
                <div class="flex flex-col gap-05 px-2">
                  <.inputs_for :let={f} field={f[:modes]}>
                    <.input
                      :for={subfield <- Modes.fields()}
                      type="checkbox"
                      field={f[subfield]}
                      label={Modes.mode_label(subfield)}
                    />
                  </.inputs_for>
                </div>
              </:content>
              <:extra :if={used_input?(f[:modes])}>
                <.feedback :for={{msg, _} <- f[:modes].errors} kind={:error}>
                  <%= msg %>
                </.feedback>
              </:extra>
            </.accordion>
          </.fieldset>
          <div class="inline-flex items-center gap-1">
            <.input type="checkbox" field={f[:wheelchair]} label="Prefer accessible routes" />
            <.icon type="icon-svg" name="icon-accessible-small" class="h-5 w-5" />
          </div>
        </div>
        <div class="col-start-2 justify-self-end">
          <.button type="submit" phx-disable-with="Planning your trip...">
            Get trip suggestions
          </.button>
        </div>
      </.form>
    </section>
    """
  end

  @impl true
  @doc """
  If the user selects "now" for the date and time, hide the datepicker.
  This will destroy the flatpickr instance.

  If the user selects arrive by or leave at, then we show the datepicker and set the time to the nearest 5 minutes.
  """
  def handle_event("toggle_datepicker", %{"input_form" => %{"datetime_type" => "now"}}, socket) do
    new_socket =
      socket
      |> assign(show_datepicker: false)
      |> push_event("set-datetime", %{datetime: nearest_5_minutes()})

    {:noreply, new_socket}
  end

  def handle_event("toggle_datepicker", _, socket) do
    new_socket =
      socket
      |> assign(show_datepicker: true)
      |> push_event("set-datetime", %{datetime: nearest_5_minutes()})

    {:noreply, new_socket}
  end

  def handle_event("handle_change", %{"input_form" => params}, socket) do
    send(self(), {:changed_form, params})

    form =
      params
      |> InputForm.validate_params()
      |> Phoenix.Component.to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  def handle_event("save_form", %{"input_form" => params}, socket) do
    {:noreply, save_form(params, socket)}
  end

  defp datepicker_config do
    %{
      default_date: Timex.now("America/New_York"),
      enable_time: true,
      max_date: Schedules.Repo.end_of_rating(),
      min_date: Timex.today("America/New_York")
    }
  end

  defp get_form_defaults(assigns) do
    assigns
    |> Map.get(:form_values, %{
      "modes" => InputForm.initial_modes(),
      "wheelchair" => true
    })
    |> Map.merge(%{
      "datetime_type" => "now",
      "datetime" => Timex.now("America/New_York")
    })
  end

  defp nearest_5_minutes do
    datetime = Timex.now("America/New_York")
    minutes = datetime.minute
    rounded_minutes = Float.ceil(minutes / 5) * 5
    added_minutes = Kernel.trunc(rounded_minutes - minutes)

    Timex.shift(datetime, minutes: added_minutes)
  end

  defp save_form(params, socket) do
    params
    |> InputForm.validate_params()
    |> Ecto.Changeset.apply_action(:update)
    |> case do
      {:ok, data} ->
        send(self(), {:updated_form, data})

        socket

      {:error, changeset} ->
        form =
          changeset
          |> Phoenix.Component.to_form()

        assign(socket, %{form: form})
    end
  end
end
