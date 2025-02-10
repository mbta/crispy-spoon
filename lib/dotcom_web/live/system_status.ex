defmodule DotcomWeb.Live.SystemStatus do
  @moduledoc """
  A temporary LiveView for showing off the system status widget until we
  put it into the homepage (and elsewhere).
  """

  use DotcomWeb, :live_view

  import DotcomWeb.Components.RoutePills
  import DotcomWeb.Components.SystemStatus.StatusLabel
  import DotcomWeb.Components.SystemStatus.Widget

  alias Dotcom.SystemStatus

  def render(assigns) do
    alerts = SystemStatus.subway_alerts_for_today()

    statuses = SystemStatus.subway_status()

    examples =
      alerts_examples()
      |> Enum.map(fn %{alerts: alerts} = example ->
        example |> Map.put(:statuses, SystemStatus.Subway.subway_status(alerts, Timex.now()))
      end)

    assigns =
      assigns
      |> assign(:alerts, alerts)
      |> assign(:statuses, statuses)
      |> assign(:examples, examples)

    Widget

    ~H"""
    <h1>Live Data</h1>
    <.system_status_widget routes_with_statuses={@statuses} />

    <h2>Alerts</h2>
    <div class="flex flex-col gap-2">
      <.alert :for={alert <- @alerts} alert={alert} />
    </div>

    <h1>Examples</h1>
    <div :for={example <- @examples} class="mb-4">
      <div class="flex gap-5">
        <.system_status_widget routes_with_statuses={example.statuses} />
        <div class="flex flex-col gap-5">
          <span class="text-lg font-bold">Alerts</span>
          <.alert :for={alert <- example.alerts} alert={alert} />
        </div>
      </div>
    </div>

    <h1>Misc Components</h1>
    <h2>Status Labels</h2>
    <div class="flex flex-col gap-2">
      <.status_label status={:normal} />
      <.status_label status={:shuttle} />
      <.status_label status={:shuttle} plural />
      <.status_label status={:shuttle} prefix="8:30pm" />
      <.status_label status={:shuttle} prefix="Wed Feb 12 - Fri Feb 14" />
      <.status_label status={:station_closure} />
      <.status_label status={:delay} />
    </div>

    <h2>Route Pills</h2>
    <div class="flex flex-col gap-2">
      <.route_pill route_id="Blue" />
      <.route_pill route_id="Green" />
      <.route_pill route_id="Orange" />
      <.route_pill route_id="Red" />
      <.route_pill_with_modifiers route_id="Green" modifier_ids={["Green-B", "Green-C"]} />
    </div>
    """
  end

  defp alert(assigns) do
    ~H"""
    <details class="border border-gray-lighter p-2">
      <summary>
        <div>
          <span class="font-bold">{@alert.effect}:</span>
          <span class="italic">
            {@alert.informed_entity
            |> Enum.map(& &1.route)
            |> Enum.uniq()
            |> Enum.sort()
            |> Enum.join(", ")}
          </span>
        </div>
        <span>{@alert.header}</span>
      </summary>
      <details>
        <summary>Raw alert</summary>
        <pre>{inspect(@alert, pretty: true)}</pre>
      </details>
    </details>
    """
  end

  defp alerts_examples() do
    [
      %{alerts: []},
      %{
        alerts: [
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :suspension,
            header: "Northbound Orange Line trains are suspended due to flooding",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Orange"}]
            }
          },
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :delay,
            header: "Southbound Orange Line trains are delayed due to flooding",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Orange"}]
            }
          },
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :delay,
            header:
              "Northbound Blue line trains are delayed due to an escaped whale from the aquarium",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Blue"}]
            }
          },
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :delay,
            header:
              "Southbound Blue line trains are delayed due to an escaped otter from the aquarium",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Blue"}]
            }
          }
        ]
      },
      %{
        alerts: [
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :shuttle,
            header:
              "Mattapan trains are replaced with shuttles that are just driving on the tracks",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Mattapan"}]
            }
          },
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :station_closure,
            header: "Copley Station is closed due to an overabundance of books",
            informed_entity: %Alerts.InformedEntitySet{
              entities: GreenLine.branch_ids() |> Enum.map(&%Alerts.InformedEntity{route: &1})
            }
          }
        ]
      },
      %{
        alerts: [
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :delay,
            header: "Green line B branch is delayed due to protests at BU",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Green-B"}]
            }
          }
        ]
      },
      %{
        alerts: [
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :delay,
            header: "Green line B branch is delayed due to protests at BU",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Green-B"}]
            }
          },
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :station_closure,
            header: "Copley Station is closed due to an over-abundance of books",
            informed_entity: %Alerts.InformedEntitySet{
              entities: GreenLine.branch_ids() |> Enum.map(&%Alerts.InformedEntity{route: &1})
            }
          }
        ]
      },
      %{
        alerts: [
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :suspension,
            header: "Northbound Orange Line trains are suspended due to flooding",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Orange"}]
            }
          },
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :delay,
            header: "Southbound Orange Line trains are delayed due to flooding",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Orange"}]
            }
          },
          %Alerts.Alert{
            active_period: [
              {Timex.beginning_of_day(Timex.now()), Timex.end_of_day(Timex.now())}
            ],
            effect: :shuttle,
            header:
              "Mattapan trains are replaced with shuttles that are just driving on the tracks",
            informed_entity: %Alerts.InformedEntitySet{
              entities: [%Alerts.InformedEntity{route: "Mattapan"}]
            }
          }
        ]
      }
    ]
  end
end
