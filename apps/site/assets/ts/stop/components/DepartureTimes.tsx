import { groupBy } from "lodash";
import React, { ReactElement } from "react";
import { Alert, DirectionId, Route } from "../../__v3api";
import renderFa from "../../helpers/render-fa";
import realtimeIcon from "../../../static/images/icon-realtime-tracking.svg";
import SVGIcon from "../../helpers/render-svg";
import {
  hasDetour,
  hasShuttleService,
  hasSuspension
} from "../../models/alert";
import Badge from "../../components/Badge";
import {
  DisplayTimeConfig,
  infoToDisplayTime
} from "../models/displayTimeConfig";
import { DepartureInfo } from "../../models/departureInfo";
import { schedulesByHeadsign } from "../../models/schedule";
import { PredictionWithTimestamp } from "../../models/perdictions";
import { isACommuterRailRoute } from "../../models/route";

const toHighPriorityAlertBadge = (alerts: Alert[]): JSX.Element | undefined => {
  if (hasSuspension(alerts)) {
    return <Badge text="Stop Closed" contextText="Route Status" />;
  }

  if (hasShuttleService(alerts)) {
    return <Badge text="Shuttle Service" contextText="Route Status" />;
  }

  return undefined;
};

const toInformativeAlertBadge = (alerts: Alert[]): JSX.Element | undefined => {
  if (hasDetour(alerts)) {
    return <Badge text="Detour" contextText="Route Status" />;
  }

  return undefined;
};

const departureTimeClasses = (
  time: DisplayTimeConfig,
  index: number
): string => {
  let customClasses = "";
  if (time.isBolded) {
    customClasses += " font-weight-bold ";
  }
  if (time.isStrikethrough) {
    // TODO keep original font color
    customClasses += " strikethrough ";
  }
  if (index === 1) {
    // All secondary times should be smaller
    customClasses += " fs-14 pt-2 ";
  }
  return customClasses;
};

const displayFormattedTimes = (
  formattedTimes: DisplayTimeConfig[],
  isCR: Boolean
): JSX.Element => {
  return (
    <div className="d-flex justify-content-space-between">
      {formattedTimes.map((time, index) => {
        const classes = departureTimeClasses(time, index);
        return (
          <div className="d-flex" key={`${time.reactKey}`}>
            {time.isPrediction && (
              <div className="me-4">
                {SVGIcon("c-svg__icon--realtime fs-10", realtimeIcon)}
              </div>
            )}
            <div className="me-8">
              <div className={`${classes} u-nowrap`}>{time.displayString}</div>
              <div className="fs-12">
                {/* Prioritize displaying Tomorrow over track name if both are present */}
                {time.isTomorrow && "Tomorrow"}
                {!time.isTomorrow &&
                  isCR &&
                  !!time.trackName &&
                  `Track ${time.trackName}`}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};

const departureTimeRow = (
  headsignName: string,
  formattedTimes: DisplayTimeConfig[],
  isCR: Boolean,
  alertBadge?: JSX.Element
): JSX.Element => {
  let alertClass = "";
  if (alertBadge && formattedTimes.length > 0) {
    // Informative badges need more padding between them and the time
    alertClass = "pt-4";
  }
  return (
    <div
      key={headsignName}
      className="departure-card__headsign d-flex justify-content-space-between"
    >
      <div className="departure-card__headsign-name">{headsignName}</div>
      <div className="d-flex align-items-center">
        <div>
          {formattedTimes.length > 0 &&
            displayFormattedTimes(formattedTimes, isCR)}
          <div className={alertClass} style={{ float: "right" }}>
            {alertBadge}
          </div>
        </div>
        <button
          type="button"
          aria-label={`Open upcoming departures to ${headsignName}`}
        >
          {renderFa("", "fa-angle-right")}
        </button>
      </div>
    </div>
  );
};

const getRow = (
  headsign: string,
  departures: DepartureInfo[],
  alerts: Alert[],
  overrideDate?: Date
): JSX.Element => {
  // High priority badges override the displaying of times
  const alertBadge = toHighPriorityAlertBadge(alerts);
  if (alertBadge) {
    return departureTimeRow(
      headsign,
      [],
      schedules[0] ? isACommuterRailRoute(schedules[0].route.type) : false,
      alertBadge
    );
  }

  // informative badges compliment the times being shown
  const informativeAlertBadge = toInformativeAlertBadge(alerts);

  // Merging should happen after alert processing incase a route is cancelled
  const formattedTimes = infoToDisplayTime(departures, overrideDate);

  return departureTimeRow(
    headsign,
    formattedTimes,
    schedules[0] ? isACommuterRailRoute(schedules[0].route.type) : false,
    informativeAlertBadge
  );
};

interface DepartureTimesProps {
  route: Route;
  directionId: DirectionId;
  departuresForDirection: DepartureInfo[];
  alertsForDirection: Alert[];
  // override date primarily used for testing
  overrideDate?: Date;
  onClick: (
    route: Route,
    directionId: DirectionId,
    departures: DepartureInfo[] | null | undefined
  ) => void;
}

const DepartureTimes = ({
  route,
  directionId,
  departuresForDirection,
  onClick,
  alertsForDirection,
  overrideDate
}: DepartureTimesProps): ReactElement<HTMLElement> => {
  const groupedDepartures = groupBy(departuresForDirection, "trip.headsign");
  return (
    <>
      {Object.entries(groupedDepartures).map(([headsign, departures]) => {
        return (
          <div
            key={`${headsign}-${route.id}`}
            onClick={() => onClick(route, directionId, departures)}
            onKeyDown={() => onClick(route, directionId, departures)}
            role="presentation"
          >
            {getRow(headsign, departures, alertsForDirection, overrideDate)}
          </div>
        );
      })}
    </>
  );
};

export { DepartureTimes as default, infoToDisplayTime };
