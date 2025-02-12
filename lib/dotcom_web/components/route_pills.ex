defmodule DotcomWeb.Components.RoutePills do
  @moduledoc """
  Reusable components for displaying subway routes.
  """

  use DotcomWeb, :component

  attr :route_id, :string, required: true
  attr :modifier_ids, :list, default: []
  attr :modifier_class, :string, default: ""

  @green_line_branches GreenLine.branch_ids()
  @subway_lines Dotcom.Routes.subway_route_ids()

  def route_pill(%{route_id: route_id} = assigns) when route_id in @green_line_branches do
    ~H"""
    <.route_pill route_id="Green" modifier_ids={[@route_id]} />
    """
  end

  def route_pill(%{route_id: "Mattapan"} = assigns) do
    ~H"""
    <.route_pill route_id="Red" modifier_ids={["Mattapan"]} />
    """
  end

  def route_pill(%{route_id: route_id, modifier_ids: []} = assigns)
      when route_id in @subway_lines do
    ~H"""
    <div class={
      [
        bg_color_class(@route_id),
        "w-[3.125rem]"
      ] ++ shared_icon_classes()
    }>
      {pill_text(@route_id)}
    </div>
    """
  end

  def route_pill(%{route_id: route_id, modifier_ids: modifier_ids} = assigns) do
    if valid_modifiers?(route_id, modifier_ids) do
      ~H"""
      <.route_pill_with_modifiers
        route_id={@route_id}
        modifier_ids={@modifier_ids}
        modifier_class={@modifier_class}
      />
      """
    else
      ~H"""
      <.unknown_route_pill />
      """
    end
  end

  def route_pill(assigns) do
    ~H"""
    <.unknown_route_pill />
    """
  end

  defp route_pill_with_modifiers(assigns) do
    ~H"""
    <span class="flex">
      <.route_pill route_id={@route_id} />
      <span class="h-6 -ml-1 flex gap-0.5">
        <.route_modifier
          :for={modifier_id <- @modifier_ids}
          modifier_id={modifier_id}
          class={@modifier_class}
        />
      </span>
    </span>
    """
  end

  defp route_modifier(assigns) do
    ~H"""
    <div class={
      [bg_color_class(@modifier_id), "ring-2 ring-white w-6"] ++
        shared_icon_classes() ++
        [@class]
    }>
      {modifier_text(@modifier_id)}
    </div>
    """
  end

  defp unknown_route_pill(assigns) do
    ~H"""
    <div class={
      [
        "bg-gray-500",
        "w-[3.125rem]"
      ] ++ shared_icon_classes()
    }>
      ?
    </div>
    """
  end

  defp pill_text(route_id) do
    (route_id |> String.at(0)) <> "L"
  end

  defp modifier_text("Green-" <> branch_id), do: branch_id
  defp modifier_text("Mattapan"), do: "M"

  defp bg_color_class("Green-" <> _), do: bg_color_class("Green")
  defp bg_color_class("Mattapan"), do: bg_color_class("Red")

  defp bg_color_class(route_id) do
    "bg-#{route_id |> String.downcase()}-line"
  end

  defp shared_icon_classes() do
    [
      "rounded-full h-6",
      "flex items-center justify-center",
      "text-white font-bold font-heading select-none leading-none"
    ]
  end

  defp valid_modifiers?("Green", modifiers) do
    modifiers |> Enum.all?(&(&1 in @green_line_branches))
  end

  defp valid_modifiers?("Red", ["Mattapan"]), do: true

  defp valid_modifiers?(_route_id, _modifiers), do: false
end
