import React from "react";
import renderer from "react-test-renderer";
import serviceData from "./serviceData.json";
import { createReactRoot } from "../../app/helpers/testUtils";
import {
  fetchData as fetchSchedule,
  ServiceSelector,
  ScheduleTableWrapper
} from "../components/schedule-finder/ServiceSelector";
import { ServiceInSelector } from "../components/__schedule";
import { Journey } from "../components/__trips";

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

describe("ServiceSelector", () => {
  it("renders with a date", () => {
    createReactRoot();
    const tree = renderer.create(
      <ServiceSelector
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

describe("ScheduleTableWrapper", () => {
  it("renders a loading message when loading", () => {
    const state = {
      isLoading: true
    };
    const tree = renderer.create(
      <ScheduleTableWrapper
        state={state}
        routePatterns={[]}
        routeId="111"
        stopId="stopId"
        directionId={0}
        selectedService={services[0]}
      />
    );
    expect(tree).toMatchSnapshot();
  });

  it("renders a ScheduleTable when there are journeys", () => {
    const journeys: Journey[] = serviceData as Journey[];
    const state = {
      isLoading: false,
      data: journeys
    };
    const tree = renderer.create(
      <ScheduleTableWrapper
        state={state}
        routePatterns={[]}
        routeId="111"
        stopId="stopId"
        directionId={0}
        selectedService={services[0]}
      />
    );
    expect(tree).toMatchSnapshot();
  });

  it("renders a no scheduled service message when there are no journeys", () => {
    const state = {
      isLoading: false,
      data: []
    };
    const tree = renderer.create(
      <ScheduleTableWrapper
        state={state}
        routePatterns={[]}
        routeId="111"
        stopId="stopId"
        directionId={0}
        selectedService={services[0]}
      />
    );
    expect(tree).toMatchSnapshot();
  });
});

describe("fetchSchedule", () => {
  it("fetches the selected schedule", async () => {
    window.fetch = jest.fn().mockImplementation(
      () =>
        new Promise((resolve: Function) =>
          resolve({
            json: () => ({
              by_trip: "by_trip_data",
              trip_order: "trip_order_data"
            }),
            ok: true,
            status: 200,
            statusText: "OK"
          })
        )
    );

    const dispatchSpy = jest.fn();

    await await fetchSchedule(
      "83",
      "stopId",
      services.find(service => service.id === "BUS319-P-Sa-02")!,
      1,
      true,
      dispatchSpy
    );

    expect(window.fetch).toHaveBeenCalledWith(
      "/schedules/finder_api/journeys?id=83&date=2019-08-31&direction=1&stop=stopId&is_current=true"
    );

    expect(dispatchSpy).toHaveBeenCalledTimes(2);
    expect(dispatchSpy).toHaveBeenCalledWith({
      type: "FETCH_STARTED"
    });
    expect(dispatchSpy).toHaveBeenCalledWith({
      payload: { by_trip: "by_trip_data", trip_order: "trip_order_data" },
      type: "FETCH_COMPLETE"
    });
  });

  it("throws an error if the fetch fails", async () => {
    window.fetch = jest.fn().mockImplementation(
      () =>
        new Promise((resolve: Function) =>
          resolve({
            ok: false,
            status: 500,
            statusText: "you broke it"
          })
        )
    );

    const dispatchSpy = jest.fn();

    await await fetchSchedule(
      "83",
      "stopId",
      services.find(service => service.id === "BUS319-P-Sa-02")!,
      1,
      true,
      dispatchSpy
    );

    expect(dispatchSpy).toHaveBeenCalledTimes(2);
    expect(dispatchSpy).toHaveBeenCalledWith({ type: "FETCH_STARTED" });
    expect(dispatchSpy).toHaveBeenCalledWith({ type: "FETCH_ERROR" });
  });
});
