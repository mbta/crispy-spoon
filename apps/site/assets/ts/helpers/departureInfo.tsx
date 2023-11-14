import React from "react";
import {
  chain,
  concat,
  difference,
  find,
  keyBy,
  keys,
  map,
  sortBy
} from "lodash";
import { PredictionWithTimestamp } from "../models/predictions";
import { ScheduleWithTimestamp } from "../models/schedules";
import { isCancelled, isDelayed, isSkipped } from "./prediction-helpers";
import { DepartureInfo } from "../models/departureInfo";
import {
  isABusRoute,
  isACommuterRailRoute,
  isSubwayRoute
} from "../models/route";
import { DirectionId, Route } from "../__v3api";
import DisplayTime from "../stop/components/DisplayTime";
import { getInfoKey } from "../stop/models/displayTimeConfig";
import { RoutePatternWithPolyline } from "../models/route-patterns";

export const SUBWAY = "subway";
export const BUS = "bus";
export const COMMUTER_RAIL = "commuter_rail";
export const FERRY = "ferry";

const toRouteMode = (
  route: Route
): typeof SUBWAY | typeof BUS | typeof COMMUTER_RAIL | typeof FERRY => {
  if (isSubwayRoute(route)) {
    return SUBWAY;
  }
  if (isABusRoute(route)) {
    return BUS;
  }
  if (isACommuterRailRoute(route)) {
    return COMMUTER_RAIL;
  }
  return FERRY;
};

const departureInfoToTime = (departureInfo: DepartureInfo): Date => {
  // If there isn't a prediction there should be a schedule
  return departureInfo.prediction && departureInfo.prediction.time
    ? departureInfo.prediction.time
    : departureInfo.schedule!.time;
};

const getNextUnCancelledDeparture = (
  departureInfos: DepartureInfo[]
): DepartureInfo | undefined => {
  return find(departureInfos, (di: DepartureInfo) => !di.isCancelled);
};

const displayInfoContainsPrediction = (
  departureInfo: DepartureInfo
): boolean => {
  return !!departureInfo.prediction;
};

const mergeIntoDepartureInfo = (
  schedules: ScheduleWithTimestamp[],
  predictions: PredictionWithTimestamp[]
): DepartureInfo[] => {
  const schedulesByTripId = keyBy(schedules, "trip.id");
  const predictionsByTripId = keyBy(predictions, "trip.id");
  const scheduleTripIds = keys(schedulesByTripId);
  const predictionTripIds = keys(predictionsByTripId);

  // All the schedules with and without predictions
  const scheduleDirectionInfo = map(
    schedulesByTripId,
    (schedule, tripId): DepartureInfo => {
      // prediction could be undefined
      const prediction = predictionsByTripId[tripId];
      return {
        prediction,
        schedule,
        route: schedule.route,
        trip: schedule.trip,
        isCancelled: isCancelled(prediction),
        isSkipped: isSkipped(prediction),
        isDelayed: isDelayed(prediction, schedule),
        routeMode: toRouteMode(schedule.route)
      };
    }
  );

  const unmatchedPredictionTripIds = difference(
    predictionTripIds,
    scheduleTripIds
  );
  // All the predictions with no schedules
  const predictionDirectionInfo = map(
    unmatchedPredictionTripIds,
    (tripId: string): DepartureInfo => {
      const prediction = predictionsByTripId[tripId];
      return {
        prediction,
        route: prediction.route,
        trip: prediction.trip,
        isCancelled: isCancelled(prediction),
        isSkipped: isSkipped(prediction),
        routeMode: toRouteMode(prediction.route)
      } as DepartureInfo;
    }
  );

  const departureInfos = concat(scheduleDirectionInfo, predictionDirectionInfo);
  const sortedDepartureInfo = sortBy(departureInfos, di => {
    // prioritize sorting by predictions
    if (di.prediction && di.prediction.time) {
      return di.prediction.time;
    }
    return di.schedule?.time;
  });

  return sortedDepartureInfo;
};

const isAtDestination = (
  stopName: string,
  route: Route,
  directionId: DirectionId
): boolean => {
  const destination = route.direction_destinations[directionId];
  if (destination) {
    return destination.includes(stopName) && !destination.includes(" or ");
  }
  return false;
};

const isCommuterRail = (departureInfo: DepartureInfo): boolean => {
  return departureInfo?.routeMode === "commuter_rail";
};

const DefaultWrapper: React.FunctionComponent<unknown> = ({ children }) => (
  <li>{children}</li>
);
/**
 * From a list of `DepartureInfo[]`, generate a list of `<DisplayTime />`.
 * Each `<DisplayTime />` will recieve the `isCR` and `targetDate` props.
 *
 * This function can optionally
 * - wrap each `<DisplayTime />` in a specified wrapper element, `WrapperEl`
 * - truncate the list to a desired `listLength` value
 */
const departuresListFromInfos = (
  departureInfos: DepartureInfo[],
  isCR: boolean,
  targetDate?: Date,
  listLength?: number,
  omitCancelledAndSkipped = false,
  WrapperEl: typeof DefaultWrapper = DefaultWrapper
): React.ReactElement[] => {
  // optional cutoff time, before which we won't show schedules.
  // just used with subway for now.
  const predictionTimeCutoff = chain(departureInfos)
    .filter(d => d.routeMode === SUBWAY)
    .maxBy("prediction.time")
    .value()?.prediction!.time;

  return chain(departureInfos)
    .reject(
      departure =>
        omitCancelledAndSkipped &&
        (!!departure.isCancelled || !!departure.isSkipped)
    )
    .omitBy(
      ({ prediction, schedule }) =>
        // omit schedule-only departures that are before latest prediction time
        predictionTimeCutoff &&
        !prediction &&
        schedule &&
        schedule.time <= predictionTimeCutoff
    )
    .map(d => (
      <WrapperEl key={getInfoKey(d)}>
        <DisplayTime departure={d} isCR={isCR} targetDate={targetDate} />
      </WrapperEl>
    ))
    .slice(0, listLength)
    .value();
};

const departureInfoInRoutePatterns = (
  departureInfo: DepartureInfo,
  routePatterns: RoutePatternWithPolyline[]
): boolean => {
  const isMatch = !!routePatterns.find(
    rp => rp.id === departureInfo.trip.route_pattern_id
  );
  // This second case is needed for the edge case where the route pattern is
  // canonical but the schedules/predictions are not serving canonical route
  // patterns (e.g. due to shuttles or other disruptions)
  const isSimilar = !!routePatterns.find(
    rp =>
      rp.headsign === departureInfo.trip.headsign &&
      rp.route_id === departureInfo.route.id
  );
  return isMatch || isSimilar;
};

export {
  mergeIntoDepartureInfo,
  departureInfoToTime,
  displayInfoContainsPrediction,
  getNextUnCancelledDeparture,
  isAtDestination,
  isCommuterRail,
  departuresListFromInfos,
  departureInfoInRoutePatterns
};
