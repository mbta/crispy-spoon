defmodule DotcomWeb.Live.Admin.TripPlanFeedback do
  @moduledoc """
  View for downloading data saved from the Trip Planner feedback form.
  """

  use DotcomWeb, :live_view

  alias DotcomWeb.TripPlan.Feedback

  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       :feedback,
       Feedback.get_cached_data()
     )}
  end

  def render(assigns) do
    ~H"""
    <h1>Trip Planner Feedback</h1>
    <p>
      In March 2024, we started offering a feedback form for riders to complete after making plans via the trip planner. This button lets you download the comments, along with the list of itineraries being commented on and some context from the request. In the future this might allow some filtering by date, but for now the button will give you the entire dataset.
    </p>
    <%= link(
      "Download #{Enum.count(@feedback)} #{Inflex.inflect("record", Enum.count(@feedback))} (.csv)",
      to: DotcomWeb.Router.Helpers.feedback_url(@socket, :download),
      class: "btn btn-primary",
      disabled: Enum.count(@feedback) == 0
    ) %>
    """
  end
end
