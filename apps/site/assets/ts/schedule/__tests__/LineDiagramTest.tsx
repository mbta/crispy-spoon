import React from "react";
import renderer from "react-test-renderer";
import { mount } from "enzyme";
import LineDiagram from "../components/LineDiagram";
import { StopType } from "../../__v3api";
import { LineDiagramStop } from "../components/__schedule";
const stopType = "stop" as StopType;
// Not a full line diagram

export const lineDiagram = [
  {
    stop_data: [{ type: "terminus", branch: null }],
    route_stop: {
      zone: "1A",
      stop_features: ["bus"],
      station_info: {
        type: stopType,
        "station?": false,
        platform_name: null,
        platform_code: null,
        parking_lots: [],
        parent_id: null,
        note: null,
        name: "Elm St opp Haskell Ave",
        municipality: "Boston",
        longitude: -71.033138,
        latitude: 42.415684,
        "is_child?": false,
        id: "5547",
        "has_fare_machine?": false,
        "has_charlie_card_vendor?": false,
        fare_facilities: [],
        description: null,
        closed_stop_info: null,
        child_ids: [],
        bike_storage: [],
        address: null,
        accessibility: ["unknown"]
      },
      route: {
        type: 3,
        name: "111",
        long_name: "Woodlawn - Haymarket",
        id: "111",
        direction_names: { "0": "Outbound", "1": "Inbound" },
        direction_destinations: { "0": "Woodlawn", "1": "Haymarket" },
        description: "key_bus_route",
        "custom_route?": false
      },
      name: "Elm St opp Haskell Ave",
      "is_terminus?": true,
      "is_beginning?": true,
      id: "5547",
      connections: [
        {
          type: 3,
          name: "110",
          long_name: "Wonderland - Wellington",
          id: "110",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: { "0": "Wonderland", "1": "Wellington" },
          description: "local_bus",
          "custom_route?": false
        }
      ],
      closed_stop_info: null,
      branch: null
    },
    alerts: []
  },
  {
    stop_data: [{ type: "stop", branch: "Lowell" }],
    route_stop: {
      zone: "1A",
      stop_features: [
        "orange_line",
        "green_line_c",
        "green_line_e",
        "commuter_rail",
        "access",
        "parking_lot"
      ],
      station_info: {
        type: "station",
        "station?": true,
        platform_name: null,
        platform_code: null,
        parking_lots: [
          {
            utilization: null,
            payment: {
              monthly_rate: "$380 restricted",
              mobile_app: null,
              methods: ["Credit/Debit Card", "Cash"],
              daily_rate:
                "Hourly: 30 Min: $8, 1 hr: $15, 1-2 hrs: $22, 2-3 hrs: $26, 3-12 hrs: $30 | Daily Max: $68 | Events: $48 | Early Bird (in by 9 AM, out by 6 PM): $24 | Nights/Weekends: $10"
            },
            note: "Parking garage is located underneath TD Garden.",
            name: "North Station Garage",
            manager: {
              url:
                "https://www.propark.com/propark-locator2/north-station-garage/",
              phone: "617-222-3042",
              name: "ProPark",
              contact: "ProPark"
            },
            longitude: -71.06214,
            latitude: 42.366083,
            capacity: {
              type: "Garage",
              total: 1275,
              overnight: "Unknown",
              accessible: 38
            },
            address: null
          }
        ],
        parent_id: null,
        note: null,
        name: "North Station",
        municipality: "Boston",
        longitude: -71.06129,
        latitude: 42.365577,
        "is_child?": false,
        id: "place-north",
        "has_fare_machine?": true,
        "has_charlie_card_vendor?": true,
        fare_facilities: [
          "fare_media_assistant",
          "fare_vending_machine",
          "ticket_window"
        ],
        description: null,
        closed_stop_info: null,
        child_ids: [
          "70026",
          "70027",
          "70205",
          "70206",
          "North Station",
          "North Station-01",
          "North Station-02",
          "North Station-03",
          "North Station-04",
          "North Station-05",
          "North Station-06",
          "North Station-07",
          "North Station-08",
          "North Station-09",
          "North Station-10",
          "door-north-causewaye",
          "door-north-causeways",
          "door-north-crcanal",
          "door-north-crcauseway",
          "door-north-crnashua",
          "door-north-tdgarden",
          "door-north-valenti"
        ],
        bike_storage: ["bike_storage_rack"],
        address: "135 Causeway St, Boston MA 02114",
        accessibility: [
          "accessible",
          "escalator_both",
          "elevator",
          "fully_elevated_platform",
          "portable_boarding_lift"
        ]
      },
      route: {
        type: 2,
        name: "Lowell Line",
        long_name: "Lowell Line",
        id: "CR-Lowell",
        direction_names: { "0": "Outbound", "1": "Inbound" },
        direction_destinations: { "0": "Lowell", "1": "North Station" },
        description: "commuter_rail",
        "custom_route?": false
      },
      name: "North Station",
      "is_terminus?": true,
      "is_beginning?": true,
      id: "place-north",
      connections: [
        {
          type: 1,
          name: "Orange Line",
          long_name: "Orange Line",
          id: "Orange",
          direction_names: { "0": "Southbound", "1": "Northbound" },
          direction_destinations: { "0": "Forest Hills", "1": "Oak Grove" },
          description: "rapid_transit",
          "custom_route?": false
        },
        {
          type: 0,
          name: "Green Line C",
          long_name: "Green Line C",
          id: "Green-C",
          direction_names: { "0": "Westbound", "1": "Eastbound" },
          direction_destinations: {
            "0": "Cleveland Circle",
            "1": "North Station"
          },
          description: "rapid_transit",
          "custom_route?": false
        },
        {
          type: 0,
          name: "Green Line E",
          long_name: "Green Line E",
          id: "Green-E",
          direction_names: { "0": "Westbound", "1": "Eastbound" },
          direction_destinations: { "0": "Heath Street", "1": "Lechmere" },
          description: "rapid_transit",
          "custom_route?": false
        },
        {
          type: 2,
          name: "Fitchburg Line",
          long_name: "Fitchburg Line",
          id: "CR-Fitchburg",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: { "0": "Wachusett", "1": "North Station" },
          description: "commuter_rail",
          "custom_route?": false
        },
        {
          type: 2,
          name: "Haverhill Line",
          long_name: "Haverhill Line",
          id: "CR-Haverhill",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: { "0": "Haverhill", "1": "North Station" },
          description: "commuter_rail",
          "custom_route?": false
        },
        {
          type: 2,
          name: "Newburyport/Rockport Line",
          long_name: "Newburyport/Rockport Line",
          id: "CR-Newburyport",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: {
            "0": "Newburyport or Rockport",
            "1": "North Station"
          },
          description: "commuter_rail",
          "custom_route?": false
        }
      ],
      closed_stop_info: null,
      branch: null
    },
    alerts: []
  },
  {
    stop_data: [{ type: "terminus", branch: null }],
    route_stop: {
      zone: null,
      stop_features: ["bus", "access", "parking_lot"],
      station_info: {
        type: "station",
        "station?": true,
        platform_name: null,
        platform_code: null,
        parking_lots: [
          {
            utilization: null,
            payment: {
              monthly_rate: "Monthly passes are not available at MBTA garages.",
              mobile_app: null,
              methods: ["Tap Card", "Credit/Debit Card", "Cash"],
              daily_rate:
                "Mon-Fri: $9 | Sat-Sun: $3 (Prices are valid for up to 14 hours of parking. After the first 14 hours, the daily rate is $15.)"
            },
            note: null,
            name: "Alewife Garage",
            manager: {
              url: "http://www.parkmbta.com/",
              phone: "617-222-3200",
              name: "Republic Parking System",
              contact: "MBTA Customer Support"
            },
            longitude: -71.142483,
            latitude: 42.395428,
            capacity: {
              type: "Garage",
              total: 2471,
              overnight: "Available",
              accessible: 32
            },
            address: null
          }
        ],
        parent_id: null,
        note: null,
        name: "Alewife",
        municipality: "Cambridge",
        longitude: -71.142483,
        latitude: 42.395428,
        "is_child?": false,
        id: "place-alfcl",
        "has_fare_machine?": true,
        "has_charlie_card_vendor?": true,
        fare_facilities: ["fare_media_assistant", "fare_vending_machine"],
        description: null,
        closed_stop_info: null,
        child_ids: [
          "141",
          "70061",
          "Alewife-01",
          "Alewife-02",
          "door-alfcl-alewife",
          "door-alfcl-busway",
          "door-alfcl-cambridgepark",
          "door-alfcl-russell",
          "door-alfcl-steel"
        ],
        bike_storage: ["bike_storage_cage"],
        address:
          "Alewife Brook Pkwy and Cambridge Park Dr, Cambridge, MA 02140",
        accessibility: ["accessible", "escalator_both", "elevator", "ramp"]
      },
      route: {
        type: 1,
        name: "Red Line",
        long_name: "Red Line",
        id: "Red",
        direction_names: { "0": "Southbound", "1": "Northbound" },
        direction_destinations: { "0": "Ashmont/Braintree", "1": "Alewife" },
        description: "rapid_transit",
        "custom_route?": false
      },
      name: "Alewife",
      "is_terminus?": true,
      "is_beginning?": true,
      id: "place-alfcl",
      connections: [
        {
          type: 3,
          name: "62",
          long_name: "Bedford VA Hospital - Alewife",
          id: "62",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: {
            "0": "Bedford VA Hospital",
            "1": "Alewife"
          },
          description: "local_bus",
          "custom_route?": false
        },
        {
          type: 3,
          name: "67",
          long_name: "Turkey Hill - Alewife",
          id: "67",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: { "0": "Turkey Hill", "1": "Alewife" },
          description: "local_bus",
          "custom_route?": false
        },
        {
          type: 3,
          name: "76",
          long_name: "Lincoln Lab/Hanscom Air Force Base - Alewife",
          id: "76",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: {
            "0": "Lincoln Lab/Hanscom Air Force Base",
            "1": "Alewife"
          },
          description: "local_bus",
          "custom_route?": false
        },
        {
          type: 3,
          name: "79",
          long_name: "Arlington Heights - Alewife",
          id: "79",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: { "0": "Arlington Heights", "1": "Alewife" },
          description: "local_bus",
          "custom_route?": false
        },
        {
          type: 3,
          name: "84",
          long_name: "Arlmont Village - Alewife",
          id: "84",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: { "0": "Arlmont Village", "1": "Alewife" },
          description: "commuter_bus",
          "custom_route?": false
        },
        {
          type: 3,
          name: "350",
          long_name: "North Burlington - Alewife",
          id: "350",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: { "0": "North Burlington", "1": "Alewife" },
          description: "local_bus",
          "custom_route?": false
        },
        {
          type: 3,
          name: "351",
          long_name: "Oak Park/Bedford Woods - Alewife",
          id: "351",
          direction_names: { "0": "Outbound", "1": "Inbound" },
          direction_destinations: {
            "0": "Oak Park/Bedford Woods",
            "1": "Alewife"
          },
          description: "commuter_bus",
          "custom_route?": false
        }
      ],
      closed_stop_info: null,
      branch: null
    },
    alerts: [
      {
        updated_at: "Updated: 10/2/2019 06:58P",
        severity: 1,
        priority: "low",
        lifecycle: "upcoming",
        informed_entity: {
          trip: [null],
          stop: ["70061", "place-alfcl"],
          route_type: [1],
          route: ["Red"],
          entities: [
            {
              trip: null,
              stop: "70061",
              route_type: 1,
              route: "Red",
              direction_id: null,
              activities: ["board"]
            },
            {
              trip: null,
              stop: "place-alfcl",
              route_type: 1,
              route: "Red",
              direction_id: null,
              activities: ["board"]
            }
          ],
          direction_id: [null],
          activities: ["board"]
        },
        id: "335740",
        header:
          "On Saturday, October 19, the main entrance to the Alewife parking garage will close and temporarily relocate for repairs and upgrades. Access to the station will be modified during the closure.",
        effect: "station_issue",
        description:
          "Signs will be placed around the facility to direct motorists to the temporary entrance.",
        active_period: [["2019-10-19 4:30", null]]
      },
      {
        updated_at: "Updated: 10/2/2019 06:58P",
        severity: 1,
        priority: "high",
        lifecycle: "ongoing",
        informed_entity: {
          trip: [null],
          stop: ["70061", "place-alfcl"],
          route_type: [1],
          route: ["Red"],
          entities: [
            {
              trip: null,
              stop: "70061",
              route_type: 1,
              route: "Red",
              direction_id: null,
              activities: ["board"]
            },
            {
              trip: null,
              stop: "place-alfcl",
              route_type: 1,
              route: "Red",
              direction_id: null,
              activities: ["board"]
            }
          ],
          direction_id: [null],
          activities: ["board"]
        },
        id: "335741",
        header:
          "On Saturday, October 19, the main entrance to the Alewife parking garage will close and temporarily relocate for repairs and upgrades. Access to the station will be modified during the closure.",
        effect: "station_issue",
        description:
          "Signs will be placed around the facility to direct motorists to the temporary entrance.",
        active_period: [["2019-10-19 4:30", null]]
      }
    ]
  }
] as LineDiagramStop[];

describe("LineDiagram", () => {
  it("it renders", () => {
    const wrapper = renderer.create(<LineDiagram lineDiagram={lineDiagram} />);
    expect(wrapper.toJSON()).toMatchSnapshot();
  });

  it("has a tooltip for a transit connection", () => {
    const wrapper = mount(<LineDiagram lineDiagram={lineDiagram} />);
    const stopConnections = wrapper.find(
      ".m-schedule-line-diagram__connections a"
    );
    stopConnections.forEach(connectionLink => {
      const props = connectionLink.props();
      expect(props.title).toBeTruthy();
      expect(Object.entries(props)).toContainEqual(["data-toggle", "tooltip"]);
    });
  });
});
