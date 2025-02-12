defmodule DotcomWeb.Components.SystemStatus.SubwayStatus do
  @moduledoc """
  A component that renders the given `@statuses` in a table.
  """

  use DotcomWeb, :component

  import DotcomWeb.Components.RoutePills
  import DotcomWeb.Components.SystemStatus.StatusLabel

  @route_ids ["Red", "Orange", "Green", "Blue"]

  attr :subway_status, :any, required: true

  def subway_status(assigns) do
    assigns = assigns |> assign(:rows, status_to_rows(assigns.subway_status))

    ~H"""
    <div class="px-5 py-4 bg-white border-[1px] border-gray-lightest rounded-lg">
      <div class="border-gray-lightest border-b-[1px] pl-2 pb-3 flex items-center gap-2">
        <.icon type="icon-svg" name="icon-mode-subway-default" class="h-7 w-7" />
        <span class="font-heading font-bold text-[1.75rem] text-nowrap">Subway Status</span>
      </div>
      <a
        :for={row <- @rows}
        href={row.route_info.url}
        class={[
          "flex gap-2",
          !row.style.short_bottom_border && "border-gray-lightest border-b-[1px]",
          "hover:bg-brand-primary-lightest cursor-pointer group/row",
          "text-black no-underline"
        ]}
      >
        <div class={["pl-2 py-3", row.style.hide_route_pill && "invisible"]}>
          <.route_pill
            route_id={row.route_info.route_id}
            modifier_ids={row.route_info.branch_ids}
            modifier_class="group-hover/row:ring-brand-primary-lightest"
          />
        </div>
        <div class={[
          "py-3 w-full flex items-center text-nowrap",
          row.style.short_bottom_border && "border-b-[1px] border-gray-lightest"
        ]}>
          <.status_label
            status={row.status_entry.status}
            prefix={row.status_entry.prefix}
            plural={row.status_entry.plural}
          />
          <.icon name="chevron-right" class="h-3 w-2 fill-gray-lighter ml-auto mr-3" />
        </div>
      </a>
    </div>
    """
  end

  defp status_to_rows(subway_status) do
    @route_ids
    |> Enum.map(&{&1, subway_status |> Map.get(&1)})
    |> Enum.flat_map(&rows_for_route/1)
    |> Enum.map(&add_url/1)
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

  defp rows_for_route({route_id, branches_with_statuses}) do
    branches_with_statuses
    |> Enum.flat_map(&rows_for_branch_group/1)
    |> add_route_id(route_id)
  end

  defp rows_for_branch_group(%{branch_ids: branch_ids, status_entries: status_entries}) do
    status_entries
    |> rows_for_status_entries()
    |> add_branch_ids(branch_ids)
  end

  defp rows_for_status_entries(status_entries) do
    show_prefix = show_prefix?(status_entries)

    status_entries
    |> Enum.map(&row_for_status_entry(&1, show_prefix))
    |> add_short_intermediate_borders()
    |> show_first_route_pill()
  end

  defp row_for_status_entry(status_entry, show_prefix) do
    %{status: status, multiple: multiple} = status_entry
    prefix = if show_prefix, do: prefix(status_entry), else: nil

    %{
      route_info: %{},
      status_entry: %{
        status: status,
        plural: multiple,
        prefix: prefix
      },
      style: %{
        hide_route_pill: true,
        short_bottom_border: false
      }
    }
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

  defp add_short_intermediate_borders([entry]) do
    [entry]
  end

  defp add_short_intermediate_borders([first_entry | rest_of_entries]) do
    [
      first_entry |> put_in([:style, :short_bottom_border], true)
      | add_short_intermediate_borders(rest_of_entries)
    ]
  end

  defp show_prefix?(status_entries) do
    status_entries |> Enum.any?(&future?/1)
  end

  defp future?(%{time: {:future, _}}), do: true
  defp future?(_), do: false

  defp prefix(%{time: :current}), do: "Now"
  defp prefix(%{time: {:future, time}}), do: Util.kitchen_downcase_time(time)
end
