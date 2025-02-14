defmodule Dotcom.SystemStatus.Subway do
  @moduledoc """
  A module that groups alerts into statuses for the system status
  widget. See `Dotcom.SystemStatus` for more information.
  """

  alias Alerts.Alert

  @type status_time() :: :current | {:future, DateTime.t()}

  @type status_t() :: :normal | Dotcom.SystemStatus.Alerts.service_effect_t()

  @type status_entry() :: %{
          status: status_t(),
          multiple: boolean(),
          time: status_time()
        }

  @type status_entry_group() :: %{
          branch_ids: [Routes.Route.id_t()],
          status_entries: [status_entry()]
        }

  @lines ["Blue", "Green", "Orange", "Red"]
  @doc """
  Returns the route_id's for the subway lines.
  """
  def lines(), do: @lines

  @green_line_branch_id_set MapSet.new(GreenLine.branch_ids())

  @doc """
  Translates the given alerts into a map indicating the overall system
  status for each line.

  ## Example
      iex> alerts =
      ...>   [
      ...>     %Alerts.Alert{
      ...>       effect: :shuttle,
      ...>       informed_entity: Alerts.InformedEntitySet.new([%Alerts.InformedEntity{route: "Orange"}]),
      ...>       active_period: [{Timex.beginning_of_day(Timex.now()), nil}]
      ...>     }
      ...>   ]
      iex> Dotcom.SystemStatus.Subway.subway_status(alerts, Timex.now())
      %{
        "Blue" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}],
        "Orange" => [
          %{
            branch_ids: [],
            status_entries: [
              %{time: :current, status: :shuttle, multiple: false}
            ]
          }
        ],
        "Red" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}],
        "Green" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}]
      }

  Alerts for individual Green line branches are grouped together and
  presented under "Green", rather than being presented under a branch
  ID like "Green-D".

  ## Example
      iex> alerts =
      ...>   [
      ...>     %Alerts.Alert{
      ...>       effect: :delay,
      ...>       informed_entity: Alerts.InformedEntitySet.new([%Alerts.InformedEntity{route: "Green-E"}]),
      ...>       active_period: [{Timex.beginning_of_day(Timex.now()), nil}]
      ...>     }
      ...>   ]
      iex> Dotcom.SystemStatus.Subway.subway_status(alerts, Timex.now())
      %{
        "Blue" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}],
        "Orange" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}],
        "Red" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}],
        "Green" => [
          %{
            branch_ids: ["Green-E"],
            status_entries: [
              %{time: :current, status: :delay, multiple: false}
            ]
          },
          %{
            branch_ids: ["Green-B", "Green-C", "Green-D"],
            status_entries: [
              %{time: :current, status: :normal, multiple: false}
            ]
          }
        ]
      }

  The Mattapan line is usually not shown, but if it has any alerts,
  then it's shown as a branch of the Red line.

  ## Example
      iex> alerts =
      ...>   [
      ...>     %Alerts.Alert{
      ...>       effect: :suspension,
      ...>       informed_entity: Alerts.InformedEntitySet.new([%Alerts.InformedEntity{route: "Mattapan"}]),
      ...>       active_period: [{Timex.beginning_of_day(Timex.now()), nil}]
      ...>     }
      ...>   ]
      iex> Dotcom.SystemStatus.Subway.subway_status(alerts, Timex.now())
      %{
        "Blue" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}],
        "Orange" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}],
        "Red" => [
          %{
            branch_ids: [],
            status_entries: [
              %{time: :current, status: :normal, multiple: false}
            ]
          },
          %{
            branch_ids: ["Mattapan"],
            status_entries: [
              %{time: :current, status: :suspension, multiple: false}
            ]
          }
        ],
        "Green" => [%{branch_ids: [], status_entries: [%{time: :current, status: :normal, multiple: false}]}]
      }
  """
  @spec subway_status([Alert.t()], DateTime.t()) :: %{Routes.Route.id_t() => status_entry_group()}
  def subway_status(alerts, time) do
    @lines
    |> Map.new(fn line ->
      {line, nested_statuses_for_line(line, alerts, time)}
    end)
  end

  # Returns a map corresponding to a single item in the array returned
  # by groups/2.
  #
  # (Note: `line_id` in this context is not necessarily a GTFS
  # line_id. The green line branches are grouped under the green line
  # both here and in GTFS, but in GTFS, Mattapan is its own line,
  # while in this context, Mattapan is grouped under Red.)
  #
  # The exact implementation depends on which line. Green and Red have
  # branches, so they have special implementations.
  @spec nested_statuses_for_line(Routes.Route.id_t(), [Alert.t()], DateTime.t()) :: [
          status_entry_group()
        ]
  defp nested_statuses_for_line(line_id, alerts, time)

  # Green line nested-statuses implementation:
  #
  # Finds the alerts for each branch of the green line, maps them to
  # statuses, and then groups together any results that have the same
  # statuses.
  defp nested_statuses_for_line("Green", alerts, time) do
    green_line_status_entry_groups(alerts, time)
  end

  # Red line nested-statuses implementation:
  # Treat the red line statuses as normal, and add Mattapan if there
  # are any.
  defp nested_statuses_for_line("Red", alerts, time) do
    status_entry_groups("Red", alerts, time) ++ mattapan_status_entry_groups(alerts, time)
  end

  # Default implementation for a simple subway line (with no
  # branches).
  defp nested_statuses_for_line(route_id, alerts, time) do
    status_entry_groups(route_id, alerts, time)
  end

  # Groups the alerts provided into a collection of status entries for
  # the green line.
  @spec green_line_status_entry_groups([Alert.t()], DateTime.t()) :: [status_entry_group()]
  defp green_line_status_entry_groups(alerts, time) do
    GreenLine.branch_ids()
    |> alerts_for_routes(alerts)
    |> Enum.group_by(&affected_green_line_branch_ids/1)
    |> Enum.map(fn {branch_ids, alerts} ->
      %{branch_ids: branch_ids, status_entries: alerts_to_statuses(alerts, time)}
    end)
    |> maybe_add_normal_entry()
    |> Enum.map(&maybe_collapse_branch_ids/1)
    |> sort_branches()
  end

  # Given an alert, returns a sorted list of the green line branches
  # affected by that alert.
  @spec affected_green_line_branch_ids([Alert.t()]) :: [Routes.Route.id_t()]
  defp affected_green_line_branch_ids(alert) do
    alert.informed_entity.route
    |> MapSet.intersection(@green_line_branch_id_set)
    |> Enum.sort()
  end

  # Given a list of status entry groups, adds an additional "normal
  # service" entry if there are any green line branches unaccounted
  # for.
  @spec maybe_add_normal_entry([status_entry_group()]) :: [status_entry_group()]
  defp maybe_add_normal_entry(status_entry_groups) do
    affected_branches = all_affected_branches(status_entry_groups)

    normal_branches =
      MapSet.difference(@green_line_branch_id_set, affected_branches)
      |> Enum.sort()

    status_entry_groups ++ normal_status_entry_groups(normal_branches)
  end

  # Given a list of status entry groups, aggregates their branch_ids
  # into a MapSet and returns that.
  @spec all_affected_branches([status_entry_group()]) :: MapSet.t()
  defp all_affected_branches(status_entry_groups) do
    status_entry_groups
    |> Enum.map(& &1.branch_ids)
    |> Enum.reduce(MapSet.new(), fn branch_ids, set ->
      set |> MapSet.union(MapSet.new(branch_ids))
    end)
  end

  # Given a list of branches that don't have any alerts, returns a
  # status entry indicating normal service for those branches, or
  # nothing if the list of branches is empty. Returns this as a list
  # so that it can be concatenated with the alert-based status
  # entries.
  @spec normal_status_entry_groups([Routes.Route.id_t()]) :: [status_entry_group()]
  defp normal_status_entry_groups([]), do: []

  defp normal_status_entry_groups(normal_branches) do
    [
      %{
        branch_ids: normal_branches,
        status_entries: [normal_status()]
      }
    ]
  end

  # If the status entries for the group provided correspond to the
  # entire green line (all of its branches), then replace branch_id's
  # with an empty array to indicate that the status is for the whole
  # line.
  @spec maybe_collapse_branch_ids(status_entry_group()) :: status_entry_group()
  defp maybe_collapse_branch_ids(status_entry_group) do
    if status_entry_group.branch_ids == GreenLine.branch_ids() do
      %{status_entry_group | branch_ids: []}
    else
      status_entry_group
    end
  end

  # Sorts green line branches first by alert status (that is, "Normal
  # Service" should come after any other alerts), and then by branch
  # ID (so that, say statuses for "Green-B" should come ahead of
  # "Green-C").
  @spec sort_branches([status_entry_group()]) :: [status_entry_group()]
  defp sort_branches(status_entry_groups) do
    status_entry_groups
    |> Enum.sort_by(fn %{status_entries: status_entries, branch_ids: branch_ids} ->
      {status_sort_order(status_entries), branch_ids}
    end)
  end

  # Sort order used in sort_branches/1 - sorts normal statuses ahead
  # of alerts.
  @spec status_sort_order([status_entry()]) :: integer()
  defp status_sort_order([%{time: :current, status: :normal}]), do: 1
  defp status_sort_order(_), do: 0

  # Returns a list containing a single status entry group corresponding
  # to the alerts for the given route.
  @spec status_entry_groups(Routes.Route.id_t(), [Alert.t()], DateTime.t()) :: [
          status_entry_group()
        ]
  defp status_entry_groups(route_id, alerts, time) do
    route_id
    |> statuses_for_route(alerts, time)
    |> status_entry_group()
    |> then(&[&1])
  end

  # Behaves mostly like status_entry_groups/3 when applied to
  # "Mattapan", except that if the status is normal, returns an empty
  # list.
  @spec mattapan_status_entry_groups([Alert.t()], DateTime.t()) :: [status_entry_group()]
  defp mattapan_status_entry_groups(alerts, time) do
    "Mattapan"
    |> alerts_for_route(alerts)
    |> case do
      [] ->
        []

      mattapan_alerts ->
        mattapan_statuses = mattapan_alerts |> alerts_to_statuses(time)

        [status_entry_group(mattapan_statuses, ["Mattapan"])]
    end
  end

  # Returns a list of statuses corresponding to the alerts for the
  # given route.
  @spec statuses_for_route(Routes.Route.id_t(), [Alert.t()], DateTime.t()) :: [status_entry()]
  defp statuses_for_route(route_id, alerts, time) do
    route_id
    |> alerts_for_route(alerts)
    |> alerts_to_statuses(time)
  end

  # Returns a status_entry_group, to be used in the
  # status_entry_groups field in groups/2. If no branch_ids are
  # provided, then uses an empty array.
  @spec status_entry_group([status_entry()], [Routes.Route.id_t()]) ::
          status_entry_group()
  defp status_entry_group(statuses, branch_ids \\ []) do
    %{
      branch_ids: branch_ids,
      status_entries: statuses
    }
  end

  # Given `alerts` and `route_id`, filters out only the alerts
  # applicable to the given route, using the alert's "informed
  # entities".
  @spec alerts_for_route(Routes.Route.id_t(), [Alert.t()]) :: [Alert.t()]
  defp alerts_for_route(route_id, alerts) do
    alerts
    |> Enum.filter(fn %Alert{informed_entity: informed_entity} ->
      informed_entity
      |> Enum.any?(fn
        %{route: ^route_id} -> true
        %{} -> false
      end)
    end)
  end

  # Given `alerts` and `route_ids`, filters out only the alerts
  # applicable to the given routes, using the alert's "informed
  # entities".
  @spec alerts_for_routes([Routes.Route.id_t()], [Alert.t()]) :: [Alert.t()]
  defp alerts_for_routes(route_ids, alerts) do
    alerts
    |> Enum.filter(fn %Alert{informed_entity: informed_entity} ->
      informed_entity
      |> Enum.any?(&(&1.route in route_ids))
    end)
  end

  # Maps a list of alerts to a list of statuses that are formatted
  # according to the system status specifications:
  # - Identical alerts are grouped together and pluralized.
  # - Times are given as a kitchen-formatted string, nil, or "Now".
  # - Statuses are sorted alphabetically.
  @spec alerts_to_statuses([Alert.t()], DateTime.t()) :: [status_entry()]
  defp alerts_to_statuses(alerts, time) do
    alerts
    |> alerts_to_statuses_naive(time)
    |> consolidate_duplicates()
    |> sort_statuses()
  end

  # Naively maps a list of alerts to a list of statuses, where a
  # status is a simple structure with a route, a status, and a
  # few additional fields that determine how it will render in the
  # frontend.
  @spec alerts_to_statuses_naive([Alert.t()], DateTime.t()) :: [status_entry()]
  defp alerts_to_statuses_naive(alerts, time)

  # If there are no alerts, then we want a single status indicating
  # "Normal Service".
  defp alerts_to_statuses_naive([], _time) do
    [normal_status()]
  end

  # If there are alerts, then create a starting list of statuses that
  # maps one-to-one with the alerts provided.
  defp alerts_to_statuses_naive(alerts, time) do
    alerts
    |> Enum.map(fn alert ->
      alert_to_status(alert, time)
    end)
  end

  @spec normal_status() :: status_entry()
  defp normal_status() do
    %{multiple: false, status: :normal, time: :current}
  end

  # Translates an alert to a status:
  #  - The effect is humanized into a status for the status.
  #  - If the alert's already active, `time` is set to `nil`.
  #  - If the alert is in the future, `time` is set to the alert's
  #    start time
  @spec alert_to_status(Alert.t(), DateTime.t()) :: status_entry()
  defp alert_to_status(alert, time) do
    time = future_start_time(alert.active_period, time)

    %{multiple: false, status: alert.effect, time: time}
  end

  # - If the active period is in the future, returns its start_time.
  # - If the active period indicates that the alert is currently active, returns nil.
  # - Raises an error if the alert is completely in the past.
  @spec future_start_time([Alert.period_pair()], DateTime.t()) :: status_time()
  defp future_start_time(
         [{start_time, _end_time} = first_active_period | more_active_periods],
         time
       ) do
    cond do
      ends_before?(first_active_period, time) -> future_start_time(more_active_periods, time)
      starts_before?(first_active_period, time) -> :current
      true -> {:future, start_time}
    end
  end

  # Returns true if the active period ends before the time given. An
  # end-time of false indicates an indefinite active period, which
  # never ends.
  @spec ends_before?(Alert.period_pair(), DateTime.t()) :: boolean()
  defp ends_before?({_start_time, nil}, _time), do: false
  defp ends_before?({_start_time, end_time}, time), do: Timex.before?(end_time, time)

  # Returns true if the active period starts before the time given.
  @spec starts_before?(Alert.period_pair(), DateTime.t()) :: boolean()
  defp starts_before?({start_time, _end_time}, time), do: Timex.before?(start_time, time)

  # Combines statuses that have the same active time and status
  # into a single pluralized status (e.g. "Station Closures" instead
  # of "Station Closure").
  @spec consolidate_duplicates([status_entry()]) :: [status_entry()]
  defp consolidate_duplicates(statuses) do
    statuses
    |> Enum.group_by(fn %{time: time, status: status} -> {time, status} end)
    |> Enum.map(fn
      {_, [status]} -> status
      {_, [status | _]} -> status |> Map.put(:multiple, true)
    end)
  end

  # Sorts the given list of statuses first by time, then by
  # status, so that earlier statuses show up before later ones,
  # and then to keep statuses in a stable order.
  #
  # This takes advantage of the fact that `nil` is sorted before
  # anything else, which allows it to automatically sort active
  # statuses before future ones.
  # 
  # This should be called before &stringify_times/1, otherwise times
  # will get sorted lexically instead of temporally (e.g. 10:00pm will
  # get sorted ahead of 9:00pm).
  @spec sort_statuses([status_entry()]) :: [status_entry()]
  defp sort_statuses(statuses) do
    statuses
    |> Enum.sort_by(fn %{time: time, status: status} -> {time, status} end)
  end
end
