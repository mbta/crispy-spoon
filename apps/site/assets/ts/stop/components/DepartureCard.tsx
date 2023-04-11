import React, { ReactElement } from "react";
import { routeBgClass, busClass } from "../../helpers/css";
import { breakTextAtSlash } from "../../helpers/text";
import { isASilverLineRoute } from "../../models/route";
import { DirectionId, Route, Stop } from "../../__v3api";
import CRsvg from "../../../static/images/icon-commuter-rail-default.svg";
import Bussvg from "../../../static/images/icon-bus-default.svg";
import SubwaySvg from "../../../static/images/icon-subway-default.svg";
import FerrySvg from "../../../static/images/icon-ferry-default.svg";
import renderSvg from "../../helpers/render-svg";
import DepartureTimes from "./DepartureTimes";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const routeToModeIcon = (route: Route): any => {
  switch (route.type) {
    case 0:
    case 1:
      return SubwaySvg;

    case 2:
      return CRsvg;

    case 3:
      return Bussvg;

    case 4:
      return FerrySvg;

    default:
      return null;
  }
};

const DepartureCard = ({
  route,
  stop
}: {
  route: Route;
  stop: Stop;
}): ReactElement<HTMLElement> => {
  const routeName = (
    <span className={busClass(route)}>
      {isASilverLineRoute(route.id)
        ? `Silver Line ${route.name}`
        : breakTextAtSlash(route.name)}
    </span>
  );
  return (
    <li className="departure-card">
      <div className={`departure-card__route ${routeBgClass(route)}`}>
        {renderSvg("c-svg__icon", routeToModeIcon(route), true)} {routeName}
      </div>
      {Object.entries(route.direction_destinations).map(([direction_id]) => (
        <DepartureTimes
          key={`${route.id}-${direction_id}`}
          route={route}
          stop={stop}
          directionId={(direction_id as unknown) as DirectionId}
        />
      ))}
    </li>
  );
};

export default DepartureCard;
