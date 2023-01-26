import React, { ReactElement } from "react";
import { Alert, EnhancedRoute } from "../__v3api";
import { routeBgClass, busClass } from "../helpers/css";
import { isASilverLineRoute } from "../models/route";
import { alertIcon } from "../helpers/icon";
import { breakTextAtSlash } from "../helpers/text";

const RouteCardHeader = ({
  route,
  alerts
}: {
  route: EnhancedRoute;
  alerts: Alert[];
}): ReactElement<HTMLElement> => (
  <div
    className={`c-link-block h3 m-tnm-sidebar__route-name ${routeBgClass(
      route
    )}`}
  >
    <a className="c-link-block__outer-link" href={`/schedules/${route.id}`}>
      <span className="sr-only">Go to route</span>
    </a>
    <div className="c-link-block__inner">
      <span>
        <span className={busClass(route)}>
          {isASilverLineRoute(route.id)
            ? `Silver Line ${route.name}`
            : breakTextAtSlash(route.name)}
        </span>
        <span className="c-link-block__view-schedule">View schedule</span>
      </span>
      {alerts.length > 0 && (
        <a
          className="c-link-block__inner-link"
          href={`/schedules/${route.id}/alerts`}
          title="alert"
        >
          {alertIcon(
            "btn btn-sm c-svg__icon-alerts-triangle m-tnm-sidebar__route-alert"
          )}
          <span>
            {alerts.length}
            {alerts.length > 1 ? " alerts" : " alert"}
          </span>
        </a>
      )}
    </div>
  </div>
);

export default RouteCardHeader;
