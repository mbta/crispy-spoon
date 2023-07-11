import React from "react";
import { render, screen } from "@testing-library/react";
import StationInformation from "../../components/StationInformation";
import { ParkingLot, Stop } from "../../../__v3api";

const stationStop = {
  name: "First Station",
  "station?": true,
  bike_storage: ["bike_storage_rack"],
  accessibility: ["accessible", "ramp"],
  parking_lots: [] as ParkingLot[]
} as Stop;
const busStop = {
  name: "Second Pl",
  "station?": false,
  bike_storage: ["bike_storage_rack"],
  accessibility: ["accessible", "ramp"],
  parking_lots: [] as ParkingLot[]
} as Stop;

describe("StationInformation", () => {
  it("should have headings", () => {
    render(
      <StationInformation stop={stationStop} alerts={[]} facilities={[]} />
    );
    expect(
      screen.queryByRole("heading", { name: "Station Information" })
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Bringing Your Car or Bike" })
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Getting Around the Station" })
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Purchasing Fares" })
    ).toBeInTheDocument();
  });

  it("hides unneeded headings for bus stops", () => {
    render(<StationInformation stop={busStop} alerts={[]} facilities={[]} />);
    expect(
      screen.queryByRole("heading", { name: "Stop Information" })
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Bringing Your Car or Bike" })
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Getting Around the Station" })
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Purchasing Fares" })
    ).not.toBeInTheDocument();
  });
});
