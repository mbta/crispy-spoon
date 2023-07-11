import React from "react";
import { render, screen } from "@testing-library/react";
import BikeStorageAmenityCard from "../../../components/amenities/BikeStorageAmenityCard";
import { Alert } from "../../../../__v3api";

describe("BikeStorageAmenityCard", () => {
  it("should render the title", () => {
    render(
      <BikeStorageAmenityCard
        stopName="Wonderland"
        bikeStorage={["bike_storage_rack"]}
        alerts={[]}
      />
    );
    expect(screen.getByText("Bike Storage")).toBeDefined();
    screen.getByRole("button").click();
    // stopName used in the modal title
    expect(screen.getByText("Bike Storage at Wonderland")).toBeDefined();
  });
  it("should render 'Temporarily closed' if there's an alert", () => {
    render(
      <BikeStorageAmenityCard
        stopName=""
        bikeStorage={["bike_storage_cage"]}
        alerts={[{} as Alert]}
      />
    );
    expect(screen.getByText("Temporarily closed")).toBeDefined();
  });

  it("should render 'Not available' if there's no bike storage", () => {
    render(<BikeStorageAmenityCard stopName="" bikeStorage={[]} alerts={[]} />);
    expect(screen.getByText("Not available")).toBeDefined();
    expect(
      screen.getByText("This station does not have bike storage.")
    ).toBeDefined();
  });

  describe("shows text", () => {
    it("for pedal & park", () => {
      render(
        <BikeStorageAmenityCard
          stopName=""
          bikeStorage={["bike_storage_cage"]}
          alerts={[]}
        />
      );
      expect(
        screen.getByText(
          "Secured parking is available but requires Charlie Card registration in advance."
        )
      ).toBeDefined();
    });
    it("for covered", () => {
      render(
        <BikeStorageAmenityCard
          stopName=""
          bikeStorage={["bike_storage_rack_covered"]}
          alerts={[]}
        />
      );
      expect(
        screen.getByText("Covered bike racks are available.")
      ).toBeDefined();
    });
    it("for outdoor", () => {
      render(
        <BikeStorageAmenityCard
          stopName=""
          bikeStorage={["bike_storage_rack"]}
          alerts={[]}
        />
      );
      expect(
        screen.getByText("Outdoor bike racks are available.")
      ).toBeDefined();
    });
    it("for covered and outdoor", () => {
      render(
        <BikeStorageAmenityCard
          stopName=""
          bikeStorage={["bike_storage_rack", "bike_storage_rack_covered"]}
          alerts={[]}
        />
      );
      expect(
        screen.getByText("Covered and outdoor bike racks are available.")
      ).toBeDefined();
    });
    it("for stations with all bike storage", () => {
      render(
        <BikeStorageAmenityCard
          stopName=""
          bikeStorage={[
            "bike_storage_cage",
            "bike_storage_rack",
            "bike_storage_rack_covered"
          ]}
          alerts={[]}
        />
      );
      expect(
        screen.getByText(
          "Secured parking is available but requires Charlie Card registration in advance."
        )
      ).toBeDefined();
    });
  });
});
