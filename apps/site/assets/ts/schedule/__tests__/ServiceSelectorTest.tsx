import React from "react";
import renderer from "react-test-renderer";
import { createReactRoot } from "../../app/helpers/testUtils";
import serviceData from "./serviceData.json";
import ServiceSelector from "../components/schedule-finder/ServiceSelector";
import { ServiceSchedule } from "../components/__schedule.js";
import { ServiceWithServiceDate } from "../../__v3api";

const services: ServiceWithServiceDate[] = [
  {
    valid_days: [1, 2, 3, 4],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2019-07-03",
    service_date: "2019-07-10",
    removed_dates_notes: { "2019-07-04": "Independence Day" },
    removed_dates: ["2019-07-04"],
    name: "Weekday",
    id: "Weekday",
    end_date: "2019-08-30",
    description: "Weekday schedule",
    added_dates_notes: {},
    added_dates: []
  },
  {
    valid_days: [5],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2019-07-03",
    service_date: "2019-07-10",
    removed_dates_notes: { "2019-07-04": "Independence Day" },
    removed_dates: ["2019-07-04"],
    name: "Weekday",
    id: "Weekday-F",
    end_date: "2019-08-30",
    description: "Weekday schedule",
    added_dates_notes: {},
    added_dates: []
  },
  {
    valid_days: [6],
    typicality: "typical_service",
    type: "saturday",
    start_date: "2019-07-06",
    service_date: "2019-07-10",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Saturday",
    id: "Saturday",
    end_date: "2019-08-31",
    description: "Saturday schedule",
    added_dates_notes: {},
    added_dates: []
  },
  {
    valid_days: [7],
    typicality: "typical_service",
    type: "sunday",
    start_date: "2019-07-07",
    service_date: "2019-07-10",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Sunday",
    id: "Sunday",
    end_date: "2019-08-25",
    description: "Sunday schedule",
    added_dates_notes: {},
    added_dates: []
  }
] as ServiceWithServiceDate[];
const serviceSchedules = (serviceData as unknown) as ServiceSchedule;

describe("ServiceSelector", () => {
  it("it renders", () => {
    createReactRoot();
    const tree = renderer.create(
      <ServiceSelector
        services={services}
        directionId={0}
        serviceSchedules={serviceSchedules}
      />
    );
    expect(tree).toMatchSnapshot();
  });
});
