defmodule DotcomWeb.Components.Alerts do
  @moduledoc """
  Function components for rendering different styles of alerts.
  """

  use DotcomWeb, :component

  attr :alert, :map, required: true

  @doc """
  An alert that is embedded within another component.
  It does not include header information like the time range, effect, or route.
  """
  def embedded_alert(assigns) do
    ~H"""
    <div class="p-4 bg-gray-100">
      <%= if @alert.image do %>
        <img class="w-full mb-4" src={@alert.image} alt={if @alert.image_alternative_text, do: @alert.image_alternative_text, else: ""} />
      <% end %>
      <p class="my-0"><%= @alert.header %></p>
      <hr class="h-px my-4 bg-gray-200 border-0" />
      <p class="my-0"><%= @alert.description %></p>
      <%= if @alert.url do %>
        <hr class="h-px my-4 bg-gray-200 border-0" />
        <p class="my-0">
          For more information: <a href={@alert.url}><%= @alert.url %></a>
        </p>
      <% end %>
    </div>
    """
  end
end
