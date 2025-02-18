defmodule DotcomWeb.Components.SystemStatus.SubwayStatus do
  @moduledoc """
  A component that renders the given `@statuses` in a table.
  """

  use DotcomWeb, :component

  import DotcomWeb.Components, only: [bordered_container: 1, lined_list: 1, unstyled_accordion: 1]
  import DotcomWeb.Components.RouteSymbols, only: [subway_route_pill: 1]
  import DotcomWeb.Components.SystemStatus.StatusLabel

  @max_rows 5
  @route_ids ["Red", "Orange", "Green", "Blue"]

  attr :subway_status, :any, required: true

  def homepage_subway_status(assigns) do
    assigns = assigns |> assign(:rows, status_to_rows(assigns.subway_status))

    ~H"""
    <.bordered_container hide_divider>
      <:heading>
        <div class="px-2 flex items-center gap-2 mb-sm">
          <.icon type="icon-svg" name="icon-mode-subway-default" class="h-7 w-7" /> Subway Status
        </div>
      </:heading>
      <.lined_list :let={row} items={@rows}>
        <a
          href={row.route_info.url}
          style={if(row.style.hide_route_pill, do: "--tw-divide-opacity: 0")}
          class={[
            "flex gap-2",
            "hover:bg-brand-primary-lightest cursor-pointer group/row",
            "text-black no-underline font-normal"
          ]}
        >
          <div class={["pl-2 py-3", row.style.hide_route_pill && "invisible"]}>
            <.subway_route_pill
              class="group-hover/row:ring-brand-primary-lightest"
              route_ids={[row.route_info.route_id | row.route_info.branch_ids]}
            />
          </div>
          <div class={[
            "flex items-center justify-between grow text-nowrap gap-sm",
            row.style.hide_route_pill && "border-t-[1px] border-gray-lightest"
          ]}>
            <.status_label
              status={row.status_entry.status}
              prefix={row.status_entry.prefix}
              plural={row.status_entry.plural}
            />
            <.icon name="chevron-right" class="h-3 w-2 fill-gray-lighter ml-3 mr-2" />
          </div>
        </a>
      </.lined_list>
    </.bordered_container>
    """
  end

  def alerts_subway_status(assigns) do
    assigns = assigns |> assign(:rows, status_to_alerts_rows(assigns.subway_status))

    ~H"""
    <.bordered_container hide_divider>
      <:heading>
        <div class="px-2 mb-sm">
          Current Status
        </div>
      </:heading>
      <.lined_list :let={row} items={@rows}>
        <%= if row.alert do %>
          <.unstyled_accordion
            style={if(row.style.hide_route_pill, do: "--tw-divide-opacity: 0")}
            summary_class="hover:bg-brand-primary-lightest cursor-pointer group/row flex items-center grow text-nowrap"
            chevron_class={"fill-gray-lighter px-2 py-3 #{row.style.hide_route_pill && "border-t-[1px] border-gray-lightest"}"}
          >
            <:heading>
              <div class={["pl-2 py-3 pr-sm", row.style.hide_route_pill && "invisible"]}>
                <.subway_route_pill
                  class="group-hover/row:ring-brand-primary-lightest"
                  route_ids={[row.route_info.route_id | row.route_info.branch_ids]}
                />
              </div>
              <div class={[
                "flex items-center justify-between grow text-nowrap gap-sm py-3",
                row.style.hide_route_pill && "border-t-[1px] border-gray-lightest"
              ]}>
                <.status_label
                  status={row.status_entry.status}
                  prefix={row.status_entry.prefix}
                  plural={row.status_entry.plural}
                />
              </div>
            </:heading>
            <:content>
              {Phoenix.View.render_one(row.alert, DotcomWeb.AlertView, "_item.html",
                date_time: Util.now()
              )}
            </:content>
          </.unstyled_accordion>
        <% else %>
          <div class="flex gap-sm" style={if(row.style.hide_route_pill, do: "--tw-divide-opacity: 0")}>
            <div class={["pl-2 py-3", row.style.hide_route_pill && "invisible"]}>
              <.subway_route_pill
                class="group-hover/row:ring-brand-primary-lightest"
                route_ids={[row.route_info.route_id | row.route_info.branch_ids]}
              />
            </div>
            <div class={[
              "flex items-center justify-between grow text-nowrap gap-sm",
              row.style.hide_route_pill && "border-t-[1px] border-gray-lightest"
            ]}>
              <.status_label
                status={row.status_entry.status}
                prefix={row.status_entry.prefix}
                plural={row.status_entry.plural}
              />
            </div>
          </div>
        <% end %>
      </.lined_list>
    </.bordered_container>
    """
  end

  defp status_to_rows(subway_status) do
    @route_ids
    |> Enum.map(&{&1, subway_status |> Map.get(&1)})
    |> Enum.flat_map(&rows_for_route/1)
    |> maybe_collapse_rows()
    |> Enum.map(&add_url/1)
  end

  defp status_to_alerts_rows(subway_status) do
    @route_ids
    |> Enum.map(&{&1, subway_status |> Map.get(&1)})
    |> Enum.flat_map(&rows_for_route(&1, false))
  end

  defp maybe_collapse_rows(rows) when length(rows) > @max_rows, do: collapse_rows(rows)
  defp maybe_collapse_rows(rows), do: rows

  defp collapse_rows([
         %{route_info: %{route_id: "Green"}} = row1,
         %{route_info: %{route_id: "Green"}, status_entry: %{status: :normal}} = row2
         | rest_of_rows
       ]) do
    [row1 | collapse_rows([row2 | rest_of_rows])]
  end

  defp collapse_rows([
         %{route_info: %{route_id: "Green", branch_ids: branch_ids1}} = row1,
         %{route_info: %{route_id: "Green", branch_ids: branch_ids2}}
         | rest_of_rows
       ]) do
    combined_branch_ids =
      if Enum.empty?(branch_ids1) || Enum.empty?(branch_ids2) do
        []
      else
        (branch_ids1 ++ branch_ids2)
        |> Enum.uniq()
        |> Enum.sort()
        |> collapse_if_all_green_line()
      end

    combined_row =
      row1
      |> Map.put(:status_entry, see_alerts_status())
      |> put_in([:route_info, :branch_ids], combined_branch_ids)

    [combined_row | rest_of_rows] |> collapse_rows()
  end

  defp collapse_rows([
         %{route_info: %{route_id: route_id1}} = row1,
         %{route_info: %{route_id: route_id2}} = _row2
         | rest_of_rows
       ])
       when route_id1 == route_id2 do
    combined_row =
      row1 |> Map.put(:status_entry, see_alerts_status())

    [combined_row | rest_of_rows] |> collapse_rows()
  end

  defp collapse_rows([row1 | rest_of_rows]) do
    [row1 | collapse_rows(rest_of_rows)]
  end

  defp collapse_rows([]) do
    []
  end

  defp collapse_if_all_green_line(branch_ids) do
    if branch_ids == GreenLine.branch_ids() do
      []
    else
      branch_ids
    end
  end

  defp add_url(row) do
    route_id = route_id_from_route_info(row.route_info)
    sub_page = if normal?(row.status_entry), do: "line", else: "alerts"
    row |> put_in([:route_info, :url], ~p"/schedules/#{route_id}/#{sub_page}")
  end

  defp normal?(%{status: :normal}), do: true
  defp normal?(%{}), do: false

  defp route_id_from_route_info(%{branch_ids: [branch_id]}), do: branch_id
  defp route_id_from_route_info(%{route_id: route_id}), do: route_id

  defp rows_for_route({route_id, branches_with_statuses}, collapse_alerts? \\ true) do
    branches_with_statuses
    |> Enum.flat_map(&rows_for_branch_group(&1, collapse_alerts?))
    |> add_route_id(route_id)
  end

  defp rows_for_branch_group(
         %{branch_ids: branch_ids, status_entries: status_entries},
         collapse_alerts?
       ) do
    status_entries
    |> rows_for_status_entries(collapse_alerts?)
    |> add_branch_ids(branch_ids)
  end

  defp rows_for_status_entries(status_entries, collapse_alerts?) do
    show_prefix = show_prefix?(status_entries)

    status_entries
    |> Enum.flat_map(&rows_for_status_entry(&1, show_prefix, collapse_alerts?))
    |> show_first_route_pill()
  end

  defp rows_for_status_entry(%{alerts: []}, _, _) do
    [
      %{
        alert: nil,
        route_info: %{},
        status_entry: %{
          status: :normal,
          plural: false,
          prefix: nil
        },
        style: %{
          hide_route_pill: true
        }
      }
    ]
  end

  defp rows_for_status_entry(%{alerts: alerts} = status_entry, show_prefix, false) do
    prefix = if show_prefix, do: prefix(status_entry), else: nil

    for alert <- alerts do
      %{
        alert: alert,
        route_info: %{},
        status_entry: %{
          status: alert.effect,
          plural: false,
          prefix: prefix
        },
        style: %{
          hide_route_pill: true
        }
      }
    end
  end

  defp rows_for_status_entry(status_entry, show_prefix, _) do
    %{status: status, multiple: multiple} = status_entry
    prefix = if show_prefix, do: prefix(status_entry), else: nil

    [
      %{
        alerts: [],
        route_info: %{},
        status_entry: %{
          status: status,
          plural: multiple,
          prefix: prefix
        },
        style: %{
          hide_route_pill: true
        }
      }
    ]
  end

  defp add_branch_ids(rows, branch_ids) do
    rows
    |> Enum.map(fn row -> row |> put_in([:route_info, :branch_ids], branch_ids) end)
  end

  defp add_route_id(rows, route_id) do
    rows
    |> Enum.map(fn row -> row |> put_in([:route_info, :route_id], route_id) end)
  end

  defp show_first_route_pill([first_entry | rest_of_entries]) do
    [
      first_entry |> put_in([:style, :hide_route_pill], false)
      | rest_of_entries
    ]
  end

  defp show_prefix?(status_entries) do
    status_entries |> Enum.any?(&future?/1)
  end

  defp future?(%{time: {:future, _}}), do: true
  defp future?(_), do: false

  defp prefix(%{time: :current}), do: "Now"
  defp prefix(%{time: {:future, time}}), do: Util.kitchen_downcase_time(time)

  defp see_alerts_status(), do: %{status: :see_alerts, prefix: nil, plural: false}
end
