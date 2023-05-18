import React, { ReactElement, useState } from "react";
import { Dictionary, chain } from "lodash";
import { DirectionId, Route, Stop } from "../../__v3api";
import { ScheduleWithTimestamp } from "../../models/schedules";
import StopPageDepartures from "./StopPageDepartures";
import StopMapRedesign from "./StopMapRedesign";
import { RouteWithPolylines } from "../../hooks/useRoute";
import DepartureList from "./DepartureList";

interface DeparturesAndMapProps {
  routes: Route[];
  stop: Stop;
  schedules: ScheduleWithTimestamp[];
  routesWithPolylines: RouteWithPolylines[];
}

const DeparturesAndMap = ({
  routes,
  stop,
  schedules,
  routesWithPolylines
}: DeparturesAndMapProps): ReactElement<HTMLElement> => {
  const [departureInfo, setDepartureInfo] = useState<{
    departureRoute: Route | null;
    departureDirectionId: DirectionId | null;
    departureSchedules: Dictionary<ScheduleWithTimestamp[]> | null | undefined;
  }>({
    departureRoute: null,
    departureDirectionId: null,
    departureSchedules: null
  });

  const setDepartureVariables: (
    route: Route,
    directionId: DirectionId,
    departures: Dictionary<ScheduleWithTimestamp[]> | null | undefined
  ) => void = (route, directionId, allDepartures) => {
    setDepartureInfo({
      departureRoute: route,
      departureDirectionId: directionId,
      departureSchedules: allDepartures
    });
  };

  const polylines = chain(routesWithPolylines)
    .orderBy("sort_order", "desc")
    .flatMap("polylines")
    .uniqBy("id")
    .value();

  const viewAllRoutes: () => boolean = () => {
    if (
      !departureInfo.departureRoute &&
      !departureInfo.departureDirectionId &&
      !departureInfo.departureSchedules
    ) {
      return true;
    }
    return false;
  };

  return (
    <div className="stop-routes-and-map">
      {viewAllRoutes() ? (
        <StopPageDepartures
          routes={routes}
          stop={stop}
          schedules={schedules}
          onClick={setDepartureVariables}
        />
      ) : (
        <div className="departures-container">
          <button
            type="button"
            onClick={() =>
              setDepartureInfo({
                departureRoute: null,
                departureDirectionId: null,
                departureSchedules: null
              })
            }
          >
            {`Back to all ${stop.name}`}
          </button>
          <div className="placeholder-map">imagine a nap</div>
          <div className="placeholder-departures">
            {`Route ${departureInfo.departureRoute?.id}`}
            {departureInfo.departureDirectionId &&
            departureInfo.departureSchedules &&
            departureInfo.departureRoute ? (
              <DepartureList
                route={departureInfo.departureRoute}
                stop={stop}
                schedules={departureInfo.departureSchedules}
                directionId={departureInfo.departureDirectionId}
              />
            ) : (
              <div>No upcoming trips today</div>
            )}
          </div>
        </div>
      )}
      <div>
        <StopMapRedesign stop={stop} lines={polylines} />
      </div>
    </div>
  );
};

export default DeparturesAndMap;
