import React, { ReactElement } from "react";
import { EnhancedRoute } from "../__v3api";
import { routeBgClass, busClass } from "../helpers/css";
import { isASilverLineRoute } from "../models/route";
import { alertIcon } from "../helpers/icon";

const RouteCardHeader = ({
  route,
  hasAlert
}: {
  route: EnhancedRoute;
  hasAlert?: boolean;
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
      <span className={busClass(route)}>
        {isASilverLineRoute(route.id)
          ? `Silver Line ${route.name}`
          : route.name}
      </span>
      {hasAlert && (
        <a
          className="c-link-block__inner-link"
          href={`/schedules/${route.id}/alerts`}
          title="alert"
        >
          {alertIcon("c-svg__icon-alerts-triangle m-tnm-sidebar__route-alert")}
        </a>
      )}
    </div>
  </div>
);

export default RouteCardHeader;
