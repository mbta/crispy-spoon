defmodule DotcomWeb.Components do
  @moduledoc """
  Shared simple functional components. These components don't manage state and
  events -- those should utilize LiveView/LiveComponents or some other
  technology.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: DotcomWeb.Endpoint,
    router: DotcomWeb.Router

  embed_templates "layouts/*"

  attr(:id, :string, required: true, doc: "A unique identifier for this search input.")

  attr(:placeholder, :string,
    required: false,
    doc: "Placeholder text for empty search bar.",
    default: "Search for routes, info, and more"
  )

  attr(:config_type, :string,
    required: true,
    doc:
      "A mapping to the AlgoliaJS configuration described in assets/ts/ui/autocomplete/config.ts",
    values: [
      "basic-config",
      "transit-near-me",
      "retail-locations",
      "proposed-locations",
      "trip-planner"
    ]
  )

  slot(:inner_block,
    required: false,
    doc:
      "Additional content to render beneath the autocomplete component. With config_type='trip-planner', this can be used to render additional form elements to capture additional details about selected locations."
  )

  @doc """
  Instantiates a search box using Algolia's Autocomplete.js library, configured
  to search our application's Algolia indexes, AWS Location Service, and
  potentially more!

  ### Usage

  A unique ID value is required. A config_type value is required and must map to
  a configuration defined on the frontend, exported in
  assets/ts/ui/autocomplete/config.ts. This frontend configuration must refer to
  a JavaScript object of the AutocompleteSource type, and handle fetching search
  results and rendering them.

  ```elixir
  <.algolia_autocomplete id="transit-near-me-locations" config_type="transit-near-me" placeholder="Find transit near a location" />
  <.algolia_autocomplete id="cms-search" config_type="my-custom-project-search-config" placeholder="Find a project" />
  ```
  """
  def algolia_autocomplete(assigns) do
    assigns =
      assigns
      |> assign_new(:config_type, fn -> false end)

    ~H"""
    <div>
      <div id={@id} phx-hook="AlgoliaAutocomplete" phx-update="ignore">
        <div
          class="c-search-bar__autocomplete"
          data-placeholder={@placeholder}
          data-config={@config_type}
        />
        <div class="c-search-bar__autocomplete-results" />
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  def error_container(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> nil end)
      |> assign_new(:padding_class, fn %{title: title} ->
        if(title, do: "p-6", else: "px-4 py-2")
      end)

    ~H"""
    <div class={"error-container rounded #{@padding_class}"}>
      <p :if={@title} class="font-bold mb-2">{@title}</p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot(:heading, required: false, doc: "Large title shown at top of container.")
  slot(:inner_block, required: true)
  attr(:hide_divider, :boolean, required: false, default: false)

  @doc """
  A generic "card" sort of component, with an optional large header block.

  Example usage:

  ```elixir
  <.bordered_container>
    <:heading>Title on Top</:heading>
    <p class="text-yellow-600">
      <strong>Whatever</strong> else inside.
    </p>
  </.bordered_container>
  ```

  Can omit the divider between the heading and content using
  `hide_divider={true}`.

  ```elixir
  <.bordered_container hide_divider>
    <:heading>
      <div class="flex justify-between">
        Slightly elaborate
        <mark>Thing</mark>
      </div>
    </:heading>
    <p class="border-t-4 border-t-brand-primary p-6 bg-brand-primary-lightest">
      Got my own dividing line
    </p>
  </.bordered_container>
  ```
  """
  def bordered_container(assigns) do
    ~H"""
    <div class="px-5 py-4 border-[1px] bg-white border-gray-lightest rounded-lg">
      <div :if={@heading} class="font-heading font-bold text-[1.75rem] text-nowrap">
        {render_slot(@heading)}
      </div>
      <hr :if={!@hide_divider} class="h-px my-2 bg-gray-lightest border-0" />
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot(:inner_block, required: true)
  attr(:items, :list, required: true)

  @doc """
  Generic list with a faint dividing line between list items. The `@inner_block`
  gets repeated for every list item.

  Example usage:

  ```elixir
  <.lined_list :let={stop} items={@stops}>
    <p class="p-1 m-0 text-xl">
      {stop.name} @ {stop.address}
    </p>
  </.lined_list>
  ```

  Not recommended but possible: Removing or altering the dividing line can be
  done on a per-line basis by wrapping the line with an element which redefines
  the Tailwind CSS properties affecting the `divide-y` helper.

  ```elixir
  <.lined_list :let={thing} items={@things}>
    <%= if thing.important do %>
      <div style="--tw-divide-y-reverse: 10">
        {stop.name} has larger bottom border width
      </div>
    <% else %>
      <%= if thing.sequence > 1 do %>
        <div style="--tw-divide-opacity: 0" class="border-dashed border-t-2">
          {stop.name} has custom top border
        </div>
      <% else %>
        {stop.name} has default border
      <% end %>
    <% end %>
  </.lined_list>
  ```

  Not recommended for simple lists which should use `<ul>` or `<ol>`, as this
  does not implement the ARIA role for "list".
  """
  def lined_list(assigns) do
    ~H"""
    <div class="border-gray-lightest border-y-[1px] divide-gray-lightest divide-y-[1px]">
      <%= for item <- @items do %>
        {render_slot(@inner_block, item)}
      <% end %>
    </div>
    """
  end
end
