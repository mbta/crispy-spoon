import React from "react";
import renderer, { act } from "react-test-renderer";
import { ReactWrapper, mount } from "enzyme";
import { createReactRoot } from "../../../../../app/helpers/testUtils";
import * as dailyScheduleModule from "../DailySchedule";
import { DirectionId, Service } from "../../../../../__v3api";
import { ServiceInSelector } from "../../../__schedule";

jest.mock("../../../../../helpers/use-fetch", () => ({
  __esModule: true,
  hasData: () => true,
  isLoading: () => false,
  isNotStarted: () => true,
  default: jest.fn().mockImplementation(() => [
    {
      status: 3,
      data: [
        {
          trip: {
            shape_id: "010070",
            route_pattern_id: "1-_-0",
            name: "",
            id: "45030860",
            headsign: "Harvard",
            direction_id: 0,
            bikes_allowed: true
          },
          route: {
            type: 3,
            sort_order: 50010,
            name: "1",
            long_name: "Harvard Square - Nubian Station",
            id: "1",
            direction_names: { 0: "Outbound", 1: "Inbound" },
            direction_destinations: {
              0: "Harvard Square",
              1: "Nubian Station"
            },
            description: "key_bus_route",
            custom_route: false,
            color: "FFC72C"
          },
          departure: {
            time: "04:45 AM",
            schedule: {
              trip: {
                shape_id: "010070",
                route_pattern_id: "1-_-0",
                name: "",
                id: "45030860",
                headsign: "Harvard",
                direction_id: 0,
                bikes_allowed: true
              },
              time: "2020-08-28T04:45:00-04:00",
              stop_sequence: 12,
              stop: null,
              pickup_type: 0,
              last_stop: false,
              flag: false,
              early_departure: true
            },
            prediction: null
          }
        }
      ]
    },
    jest.fn()
  ])
}));

const services: ServiceInSelector[] = [
  {
    valid_days: [1, 2, 3, 4, 5],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2019-07-02",
    removed_dates_notes: { "2019-07-04": "Independence Day" },
    removed_dates: ["2019-07-04"],
    name: "Weekday",
    id: "BUS319-O-Wdy-02",
    end_date: "2019-08-30",
    description: "Weekday schedule",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test",
    "default_service?": true
  },
  {
    valid_days: [5],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2019-07-05",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Weekday",
    id: "BUS319-D-Wdy-02",
    end_date: "2019-08-30",
    description: "Weekday schedule",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test",
    "default_service?": false
  },
  {
    valid_days: [6],
    typicality: "typical_service",
    type: "saturday",
    start_date: "2019-07-06",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Saturday",
    id: "BUS319-P-Sa-02",
    end_date: "2019-08-31",
    description: "Saturday schedule",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test",
    "default_service?": false
  },
  {
    valid_days: [7],
    typicality: "typical_service",
    type: "sunday",
    start_date: "2019-07-07",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Sunday",
    id: "BUS319-Q-Su-02",
    end_date: "2019-08-25",
    description: "Sunday schedule",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test",
    "default_service?": false
  },
  {
    valid_days: [],
    typicality: "holiday_service",
    type: "sunday",
    start_date: "2019-07-07",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Sunday",
    id: "Bastille-Day",
    end_date: "2019-08-25",
    description: "Sunday schedule",
    added_dates_notes: { "2019-07-14": "Bastille Day" },
    added_dates: ["2019-07-14"],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test",
    "default_service?": false
  },
  {
    valid_days: [1, 2, 3, 4, 5],
    typicality: "unplanned_disruption",
    type: "weekday",
    start_date: "2019-07-15",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Weekday",
    id: "BUS319-storm",
    end_date: "2019-07-15",
    description: "Storm (reduced service)",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test",
    "default_service?": false
  },
  {
    valid_days: [1, 2, 3, 4, 5],
    typicality: "unplanned_disruption",
    type: "weekday",
    start_date: "2019-07-22",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Weekday",
    id: "BUS319-storm-1",
    end_date: "2019-07-23",
    description: "Storm (reduced service)",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test",
    "default_service?": false
  }
];

describe("DailySchedule", () => {
  it("renders with a date", () => {
    createReactRoot();
    const tree = renderer.create(
      <dailyScheduleModule.DailySchedule
        stopId="stopId"
        services={services}
        directionId={0}
        routePatterns={[]}
        routeId="111"
        today={"2019-08-31"}
      />
    );
    expect(tree).toMatchSnapshot();
  });
});

describe("fetchJourneys", () => {
  it("returns a function that fetches the selected journey", () => {
    window.fetch = jest.fn();
    const service = services.find(service => service.id === "BUS319-P-Sa-02")!;

    const fetcher = dailyScheduleModule.fetchJourneys(
      "83",
      "stopId",
      service,
      1,
      true
    );

    expect(typeof fetcher).toBe("function");

    fetcher();

    expect(window.fetch).toHaveBeenCalledWith(
      "/schedules/finder_api/journeys?id=83&date=2019-08-31&direction=1&stop=stopId&is_current=true"
    );
  });

  it("fetches journeys again when selecting a different service", async () => {
    const fetchJourneysMock = jest.spyOn(dailyScheduleModule, "fetchJourneys");

    act(() => {
      const wrapper: ReactWrapper = mount(
        <dailyScheduleModule.DailySchedule
          stopId="stopId"
          services={services}
          directionId={0}
          routePatterns={[]}
          routeId="111"
          today={"2019-08-31"}
        />
      );

      // change value in the dropdown:
      wrapper
        .find("SchedulesSelect")
        // @ts-ignore -- types for `invoke` are too restrictive
        .invoke("onSelectService")("BUS319-P-Sa-02");

      expect(fetchJourneysMock).toHaveBeenCalledTimes(2);
      fetchJourneysMock.mockRestore();
    });
  });
});

describe("parseResults", () => {
  it("passes the results through", () => {
    const response = [
      {
        trip: {
          shape_id: "010070",
          route_pattern_id: "1-_-0",
          name: "",
          id: "45030860",
          headsign: "Harvard",
          direction_id: 0,
          "bikes_allowed?": true
        },
        route: {
          type: 3,
          sort_order: 50010,
          name: "1",
          long_name: "Harvard Square - Nubian Station",
          id: "1",
          direction_names: {
            "0": "Outbound",
            "1": "Inbound"
          },
          direction_destinations: {
            "0": "Harvard Square",
            "1": "Nubian Station"
          },
          description: "key_bus_route",
          "custom_route?": false,
          color: "FFC72C"
        },
        departure: {
          time: "04:54 AM",
          schedule: {
            trip: {
              shape_id: "010070",
              route_pattern_id: "1-_-0",
              name: "",
              id: "45030860",
              headsign: "Harvard",
              direction_id: 0,
              "bikes_allowed?": true
            },
            time: "2020-08-14T04:54:00-04:00",
            stop_sequence: 19,
            stop: null,
            pickup_type: 0,
            "last_stop?": false,
            "flag?": false,
            "early_departure?": true
          },
          prediction: null
        }
      },
      {
        trip: {
          shape_id: "010070",
          route_pattern_id: "1-_-0",
          name: "",
          id: "45030861",
          headsign: "Harvard",
          direction_id: 0,
          "bikes_allowed?": true
        },
        route: {
          type: 3,
          sort_order: 50010,
          name: "1",
          long_name: "Harvard Square - Nubian Station",
          id: "1",
          direction_names: {
            "0": "Outbound",
            "1": "Inbound"
          },
          direction_destinations: {
            "0": "Harvard Square",
            "1": "Nubian Station"
          },
          description: "key_bus_route",
          "custom_route?": false,
          color: "FFC72C"
        },
        departure: {
          time: "05:09 AM",
          schedule: {
            trip: {
              shape_id: "010070",
              route_pattern_id: "1-_-0",
              name: "",
              id: "45030861",
              headsign: "Harvard",
              direction_id: 0,
              "bikes_allowed?": true
            },
            time: "2020-08-14T05:09:00-04:00",
            stop_sequence: 19,
            stop: null,
            pickup_type: 0,
            "last_stop?": false,
            "flag?": false,
            "early_departure?": true
          },
          prediction: null
        }
      }
    ];

    expect(
      dailyScheduleModule.parseResults((response as unknown) as JSON)
    ).toEqual(response);
  });
});
