import React, { ReactElement, useState } from "react";
import { uniqueId } from "lodash";
import { Mode } from "../../__v3api";
import DeparturesFilters from "./DeparturesFilters";

export const ALL = "all";
export const BUS: Mode = "bus";
export const SUBWAY: Mode = "subway";
export const FERRY: Mode = "ferry";
export const COMMUTER_RAIL: Mode = "commuter_rail";

// TODO replace with real data
const departures: any[] = [
  {
    headsign: "Fields Corner",
    routeNumber: 210,
    mode: "bus"
  },
  {
    headsign: "Columbian Square",
    routeNumber: 226,
    mode: "commuter_rail"
  },
  {
    headsign: "Quincy Center",
    routeNumber: 230,
    mode: "subway"
  },
  {
    headsign: "Montello",
    routeNumber: 230,
    mode: "ferry"
  },
  {
    headsign: "South Shore Plaza",
    routeNumber: 236,
    mode: "bus"
  }
];

const StopPageRedesign = ({
  stopId
}: {
  stopId: string;
}): ReactElement<HTMLElement> => {
  // TODO replace type with actual data type
  const [filteredDepartures, setFilteredDepartures] = useState<any[]>([]);

  return (
    <article>
      {/* Title Bar Div */}
      <header className="d-flex justify-content-space-between">
        <div>
          <h1>{stopId}</h1>
          {/* ICONS GO HERE */}
        </div>
        <div style={{ marginTop: "3.075rem" }}>
          Zone Information PLACEHOLDER
        </div>
      </header>
      {/* Route and Map Div */}
      <div className="d-flex">
        <div style={{ minWidth: "50%" }}>
          <div>Route schedules & maps / Upcoming Trips PLACEHOLDER</div>
          <div className="d-flex">
            <DeparturesFilters
              departures={departures}
              onModeChange={setFilteredDepartures}
            />
          </div>
          <ul style={{ maxHeight: "250px", overflowY: "auto" }}>
            {filteredDepartures.map(departure => (
              <li className="d-flex" key={uniqueId()}>
                <div className="me-8">{departure.routeNumber}</div>
                <div>
                  <div>{departure.headsign}</div>
                  <div className="d-flex">
                    <div>Open Schedule</div>
                    <div>View Realtime Map</div>
                  </div>
                </div>
              </li>
            ))}
          </ul>
          <button type="button">Plan your Trip PLACEHOLDER</button>
        </div>
        <div className="hidden-sm-down">
          Map PLACEHOLDER Imageine a pretty map
        </div>
      </div>
      {/* Station Information Div */}
      <footer>
        <div>Station information PLACEHOLDER</div>
        <div>Station Address PLACEHOLDER</div>
        <div>Station Status Blocks PLACEHOLDER</div>
      </footer>
    </article>
  );
};

export default StopPageRedesign;
