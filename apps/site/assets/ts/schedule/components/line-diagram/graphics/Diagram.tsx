import React, { ReactElement } from "react";
import { uniqBy } from "lodash";
import { routeToModeName } from "../../../../helpers/css";
import {
  isBranchingNode,
  isStartNode,
  largestSliceSize,
  longestPath,
  longestPathLength,
  nextStopIds,
  stopForId,
  stopIds
} from "../../../../helpers/stop-tree";
import { isAGreenLineRoute } from "../../../../models/route";
import { Alert, DirectionId, Route } from "../../../../__v3api";
import { RouteStop, StopId, StopTree } from "../../__schedule";
import { diagramWidth } from "../line-diagram-helpers";
import VehicleIcons from "../VehicleIcons";
import { LiveDataByStop } from "../__line-diagram";
import { BASE_LINE_WIDTH, DiagonalHatchPattern } from "./graphic-helpers";
import Stop from "./Stop";
import { Line, SimpleLine } from "./Line";
import Merges from "./Merges";

interface Props {
  stopTree: StopTree;
  route: Route;
  directionId: DirectionId;
  alerts: Alert[];
  liveData?: LiveDataByStop;
}

const routeName = (route: Route): string =>
  isAGreenLineRoute(route) ? "Green Line" : route.name;

const diagramDescription = (
  pathLength: number,
  route: Route,
  directionId: DirectionId
): string => {
  const text = `${pathLength} stops`;
  const {
    direction_destinations: destinations,
    direction_names: names
  } = route;
  if (destinations) {
    return `${text} going ${names[directionId]} to ${destinations[directionId]}`;
  }
  return text;
};

const hasBranchLines = (stopTree: StopTree): boolean =>
  largestSliceSize(stopTree) > 1;

const branchingDescription = (stopTree: StopTree): string => {
  const primaryPath = longestPath(stopTree);
  const branchingStops: StopId[] = primaryPath.filter(id =>
    isBranchingNode(stopTree, id)
  );
  const branchText = branchingStops.map(branchingStopId => {
    const routeStop: RouteStop = stopForId(stopTree, branchingStopId);
    const branchNames: string[] = nextStopIds(stopTree, branchingStopId)
      .filter(id => !primaryPath.includes(id))
      .map(id => stopForId(stopTree, id)?.branch || "");

    return `Use ${routeStop.name} to transfer to trains on ${branchNames.join(
      " or "
    )} branches.`;
  });
  return branchText.join("");
};

const LiveVehicleIconSet = ({
  isStart,
  stop,
  liveData
}: {
  isStart: boolean;
  stop: RouteStop;
  liveData?: LiveDataByStop;
}): ReactElement<HTMLElement> | null => {
  const stopId = stop.id;
  if (!liveData || !liveData[stopId]) return null;
  const vehicles = uniqBy(liveData[stopId].vehicles, "id");
  // Hide vehicles arriving to the origin from 'off the line'
  const vehicleData = isStart
    ? vehicles.filter(vehicle => vehicle.status === "stopped")
    : vehicles;

  return (
    <VehicleIcons
      key={`${stopId}-vehicles`}
      stop={stop}
      vehicles={vehicleData}
    />
  );
};

interface SimpleProps {
  routeStopList: RouteStop[];
  route: Route;
  directionId: DirectionId;
  alerts: Alert[];
  liveData?: LiveDataByStop;
}

const SimpleDiagram = ({
  routeStopList,
  route,
  directionId,
  alerts,
  liveData
}: SimpleProps): ReactElement<HTMLElement> => (
  <>
    {routeStopList.map((routeStop, index) => (
      <LiveVehicleIconSet
        // eslint-disable-next-line react/no-array-index-key
        key={`${index}-${routeStop.id}`}
        isStart={index === 0}
        stop={routeStop}
        liveData={liveData}
      />
    ))}
    <svg
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-labelledby="diagram-title diagram-desc"
      className={`line-diagram-svg ${routeToModeName(route)}`}
      width={`${diagramWidth(1)}px`}
      height="100%"
      style={{ left: BASE_LINE_WIDTH / 2, overflow: "visible" }}
    >
      <title id="diagram-title">Line diagram for {routeName(route)}</title>
      <desc id="diagram-desc">
        {diagramDescription(routeStopList.length, route, directionId)}
      </desc>
      <defs>{DiagonalHatchPattern()}</defs>
      {/* Draw lines between stops */
      routeStopList.map((routeStop, index) => {
        const nextStop = routeStopList[index + 1];
        if (!nextStop) return null;
        return (
          <SimpleLine
            key={`${routeStop.id}-${nextStop.id}`}
            fromId={routeStop.id}
            toId={nextStop.id}
            alerts={alerts}
          />
        );
      })}

      {/* Draw circles for each stop */
      routeStopList.map((routeStop, index) => (
        // eslint-disable-next-line react/no-array-index-key
        <Stop key={`${index}-${routeStop.id}`} stopId={routeStop.id} />
      ))}
    </svg>
  </>
);

const Diagram = ({
  stopTree,
  route,
  directionId,
  alerts,
  liveData
}: Props): ReactElement<HTMLElement> => (
  <>
    {stopIds(stopTree).map(stopId => (
      <LiveVehicleIconSet
        key={stopId}
        isStart={isStartNode(stopTree, stopId)}
        stop={stopForId(stopTree, stopId)}
        liveData={liveData}
      />
    ))}
    <svg
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-labelledby="diagram-title diagram-desc"
      className={`line-diagram-svg ${routeToModeName(route)}`}
      width={`${diagramWidth(1)}px`}
      height="100%"
      style={{ left: BASE_LINE_WIDTH / 2, overflow: "visible" }}
    >
      <title id="diagram-title">Line diagram for {routeName(route)}</title>
      <desc id="diagram-desc">
        {diagramDescription(longestPathLength(stopTree), route, directionId)}
        {hasBranchLines(stopTree) && branchingDescription(stopTree)}
      </desc>
      <defs>{DiagonalHatchPattern()}</defs>

      {/* If there are multiple branches, draw the lines and curves for those */
      hasBranchLines(stopTree) && (
        <Merges stopTree={stopTree} alerts={alerts} />
      )}

      {/* Draw lines between stops */
      stopIds(stopTree).map(stopId =>
        nextStopIds(stopTree, stopId).map(nextStopId => (
          <Line
            key={`${stopId}-${nextStopId}`}
            stopTree={stopTree}
            fromId={stopId}
            toId={nextStopId}
            alerts={alerts}
          />
        ))
      )}

      {/* Draw circles for each stop */
      stopIds(stopTree).map(stopId => (
        <Stop key={stopId} stopId={stopId} />
      ))}
    </svg>
  </>
);

export { Diagram, SimpleDiagram };
