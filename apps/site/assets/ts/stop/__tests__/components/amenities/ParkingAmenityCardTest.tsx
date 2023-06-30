import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import ParkingAmenityCard from "../../../components/amenities/ParkingAmenityCard";
import { Alert, ParkingLot, Stop } from "../../../../__v3api";

const testStop = {
  name: "Test Stop 1",
  parking_lots: [] as ParkingLot[]
} as Stop;

const testLots = [
  {
    name: "Test Lot 1",
    capacity: {
      accessible: 123,
      total: 543,
      overnight: "Available"
    },
    payment: {
      daily_rate: "$5",
      monthly_rate: "$300",
      methods: ["Mobile App"],
      mobile_app: {
        url: "Test URL",
        id: "1234"
      }
    }
  },
  {
    name: "Test Lot 2",
    capacity: {
      accessible: 0,
      total: 44,
      overnight: "Not available"
    },
    payment: {
      daily_rate: "Free",
      monthly_rate: "$100",
      methods: ["Invoice"]
    },
    latitude: 42.0,
    longitude: -70.123
  }
] as ParkingLot[];

describe("ParkingAmenityCard", () => {
  it("should render the title", () => {
    render(<ParkingAmenityCard stop={testStop} alertsForParking={[]} />);
    expect(screen.getByText("Parking")).toBeDefined();
  });

  it("should render a modal on click", async () => {
    const user = userEvent.setup();
    const localTestStop = { ...testStop, parking_lots: [{} as ParkingLot] };
    render(<ParkingAmenityCard stop={localTestStop} alertsForParking={[]} />);
    await user.click(screen.getByRole("button"));
    expect(screen.getByText("Parking at Test Stop 1")).toBeInTheDocument();
  });

  it("should list each parking lot", async () => {
    const user = userEvent.setup();
    const localTestStop = { ...testStop, parking_lots: testLots };
    render(<ParkingAmenityCard stop={localTestStop} alertsForParking={[]} />);
    await user.click(screen.getByRole("button"));
    expect(screen.getByText("Test Lot 1")).toBeInTheDocument();
    expect(screen.getByText("Test Lot 2")).toBeInTheDocument();
  });

  it("should list each lots daily, and monthly cost", async () => {
    const user = userEvent.setup();
    const localTestStop = { ...testStop, parking_lots: testLots };
    render(<ParkingAmenityCard stop={localTestStop} alertsForParking={[]} />);
    await user.click(screen.getByRole("button"));
    expect(screen.getByText("$5")).toBeInTheDocument();
    expect(screen.getByText("$300")).toBeInTheDocument();

    expect(screen.getByText("Free")).toBeInTheDocument();
    expect(screen.getByText("$100")).toBeInTheDocument();
  });

  it("should list each parking lots overnight status", async () => {
    const user = userEvent.setup();
    const localTestStop = { ...testStop, parking_lots: testLots };
    render(<ParkingAmenityCard stop={localTestStop} alertsForParking={[]} />);
    await user.click(screen.getByRole("button"));
    expect(screen.getByText("Available")).toBeInTheDocument();
    expect(screen.getByText("Not available")).toBeInTheDocument();
  });

  it("should list each parking lots capacity", async () => {
    const user = userEvent.setup();
    const localTestStop = { ...testStop, parking_lots: testLots };
    render(<ParkingAmenityCard stop={localTestStop} alertsForParking={[]} />);
    await user.click(screen.getByRole("button"));
    expect(screen.getByText("543 total parking spots")).toBeInTheDocument();
    expect(screen.getByText("123 accessible spots")).toBeInTheDocument();

    expect(screen.getByText("44 total parking spots")).toBeInTheDocument();
    expect(screen.getByText("0 accessible spots")).toBeInTheDocument();
  });

  it("should only list payment methods if each lot supports it", async () => {
    const user = userEvent.setup();
    const localTestStop = { ...testStop, parking_lots: testLots };
    render(<ParkingAmenityCard stop={localTestStop} alertsForParking={[]} />);
    await user.click(screen.getByRole("button"));
    const paymentMethods = screen.queryAllByText("Payment Methods");
    const payByPhoneArray = screen.queryAllByText("PayByPhone");
    const invoiceArray = screen.getAllByText(/Invoice/);
    expect(paymentMethods.length).toBe(2);
    expect(payByPhoneArray.length).toBe(1);
    expect(invoiceArray.length).toBe(1);
    expect(payByPhoneArray[0]).toBeInTheDocument();
    expect(invoiceArray[0]).toBeInTheDocument();
    expect(screen.getByText(/Location 1234/)).toBeInTheDocument();
  });

  it("should only show a location link if the parking lot has a latitude and longitude", async () => {
    const user = userEvent.setup();
    const localTestStop = { ...testStop, parking_lots: testLots };
    render(<ParkingAmenityCard stop={localTestStop} alertsForParking={[]} />);
    await user.click(screen.getByRole("button"));
    const directionLinks = screen.getAllByText(/Get directions/);
    expect(directionLinks.length).toBe(1);
    expect(directionLinks[0]).toBeInTheDocument();
  });

  it("shuold show alerts in the modal", async () => {
    const alerts = [
      {
        id: "1",
        description: "Test Alert",
        header: "This is a Test Alert",
        effect: "test",
        lifecycle: "new"
      }
    ] as Alert[];
    const user = userEvent.setup();
    const localTestStop = { ...testStop, parking_lots: testLots };
    render(
      <ParkingAmenityCard stop={localTestStop} alertsForParking={alerts} />
    );
    await user.click(screen.getByRole("button"));

    expect(screen.getByText(/Test Alert/)).toBeInTheDocument();
  });
});
