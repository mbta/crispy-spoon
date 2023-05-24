import React from "react";
import { render, screen } from "@testing-library/react";
import StopPageDepartures from "../components/StopPageDepartures";
import { Route, RouteType, Stop } from "../../__v3api";
import { ScheduleWithTimestamp } from "../../models/schedules";

const baseRoute = (name: string, type: RouteType): Route =>
  ({
    id: name,
    direction_destinations: { 0: "Somewhere there", 1: "Over yonder" },
    name: `${name} Route`,
    type
  } as Route);
const stop = {} as Stop;
const routeData: Route[] = [baseRoute("4B", 3), baseRoute("Magenta", 1)];
const scheduleData = [] as ScheduleWithTimestamp[];
const mockClickAction = jest.fn();

describe("StopPageDepartures", () => {
  it("renders with no data", () => {
    const { asFragment } = render(
      <StopPageDepartures
        routes={[]}
        schedules={[]}
        predictions={[]}
        onClick={mockClickAction}
        alerts={[]}
      />
    );
    expect(asFragment()).toMatchSnapshot();
    expect(screen.getByRole("list")).toBeEmptyDOMElement();
  });

  it("renders with data", () => {
    const { asFragment } = render(
      <StopPageDepartures
        routes={routeData}
        schedules={scheduleData}
        predictions={[]}
        onClick={mockClickAction}
        alerts={[]}
      />
    );
    expect(asFragment()).toMatchSnapshot();
    expect(screen.getAllByRole("list")[0]).not.toBeEmptyDOMElement();
    ["All", "Bus", "Subway"].forEach(name => {
      expect(
        screen.getByRole("button", { name: new RegExp(name) })
      ).toBeDefined();
    });
  });

  it("doesn't show the filters if there is 1 mode present", () => {
    render(
      <StopPageDepartures
        routes={[routeData[0]]}
        schedules={scheduleData}
        predictions={[]}
        onClick={() => {}}
        alerts={[]}
      />
    );
    expect(
      screen.queryByRole("button", { name: new RegExp("All") })
    ).toBeNull();
  });
});
