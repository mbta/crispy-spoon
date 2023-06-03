import { add } from "date-fns";
import React from "react";
import { ScheduleWithTimestamp } from "../../models/schedules";
import { baseRoute } from "./helpers";
import { Alert, Stop } from "../../__v3api";
import DepartureList from "../components/DepartureList";
import { render, screen } from "@testing-library/react";
import * as predictionsChannel from "../../hooks/usePredictionsChannel";
import { PredictionWithTimestamp } from "../../models/perdictions";

const stop = {
  id: "test-stop",
  name: "Test Stop",
  latitude: 42.3519,
  longitude: 71.0552
} as Stop;
const route = baseRoute("TestRoute", 3);

const schedules = [
  {
    route: route,
    stop: stop,
    trip: {
      id: "1",
      headsign: "TestRoute Route",
      direction_id: 1,
      route_pattern_id: "Blue-6-1"
    },
    time: add(Date.now(), { minutes: 10 })
  },
  {
    route: route,
    stop: stop,
    trip: { id: "2", headsign: "TestRoute Route", direction_id: 0 },
    time: add(Date.now(), { minutes: 15 })
  },
  {
    route: route,
    stop: stop,
    trip: { id: "4", headsign: "TestRoute Route", direction_id: 1 },
    time: add(Date.now(), { minutes: 20 })
  }
] as ScheduleWithTimestamp[];

const predictionTime = add(Date.now(), { minutes: 11 });
jest.spyOn(predictionsChannel, "default").mockImplementation(() => {
  return {
    "TestRoute Route": [
      {
        time: new Date("2022-04-27T11:15:00-04:00"),
        trip: schedules[0].trip
      },
      {
        trip: schedules[1].trip,
        time: predictionTime
      }
    ] as PredictionWithTimestamp[]
  };
});

describe("DepartureList", () => {
  it("should render a schedule when no predictions available", () => {
    const { container } = render(
      <DepartureList
        route={route}
        stop={stop}
        schedules={schedules}
        directionId={0}
        alerts={[]}
      />
    );

    expect(container.querySelector("time")).toBeDefined();
    expect(container.querySelectorAll("time")[2]).toHaveAttribute(
      "datetime",
      schedules[2].time.toISOString()
    );
  });

  it("should render a prediction time if available", () => {
    const { container } = render(
      <DepartureList
        route={route}
        stop={stop}
        schedules={schedules}
        directionId={0}
        alerts={[]}
      />
    );
    expect(container.querySelector("time")).toBeDefined();
    const datetimes = Array.from(container.querySelectorAll("time")).map(el =>
      el.getAttribute("datetime")
    );
    expect(datetimes).toContain(predictionTime.toISOString());
  });

  it("header has link to schedule page variant ", () => {
    render(
      <DepartureList
        route={route}
        stop={stop}
        schedules={schedules}
        directionId={0}
        alerts={[]}
      />
    );
    expect(
      screen.getByRole("link", { name: "View all schedules" })
    ).toHaveAttribute(
      "href",
      "../schedules/TestRoute/line?schedule_direction[direction_id]=0&schedule_direction[variant]=Blue-6-1&schedule_finder[direction_id]=0&schedule_finder[origin]=test-stop"
    );
  });

  it("renders alert cards when alert is detour, suspension, or shuttle", () => {
    const alerts = [
      {
        id: "1234",
        informed_entity: {
          direction_id: [0]
        },
        effect: "shuttle"
      },
      {
        id: "4321",
        informed_entity: {
          direction_id: [null]
        },
        effect: "suspension"
      },
      {
        id: "0987",
        informed_entity: {
          direction_id: [1]
        },
        effect: "detour"
      },
      {
        id: "1234",
        informed_entity: {
          direction_id: [0]
        },
        effect: "delay"
      }
    ] as Alert[];
    render(
      <DepartureList
        route={route}
        stop={stop}
        schedules={schedules}
        directionId={0}
        alerts={alerts}
      />
    );

    expect(screen.queryByText("Shuttle Service")).toBeDefined();
    expect(screen.queryByText("Detour")).toBeDefined();
    expect(screen.queryByText("Suspension")).toBeDefined();
    expect(screen.queryByText("Delay")).toBeNull();
  });

  it("subheading includes stop + headsign name", () => {
    render(
      <DepartureList
        route={route}
        stop={stop}
        schedules={schedules}
        directionId={0}
        alerts={[]}
      />
    );
    expect(
      screen.getByRole("heading", { name: `${stop.name} to TestRoute Route` })
    ).toBeDefined();
  });

  it("should render `No upcoming trips today` if there are no schedules", () => {
    jest.spyOn(predictionsChannel, "default").mockImplementation(() => {
      return {};
    });
    render(
      <DepartureList
        alerts={[]}
        route={route}
        stop={stop}
        schedules={[]}
        directionId={0}
      />
    );
    expect(screen.getByText("No upcoming trips today")).toBeDefined();
  });
});
