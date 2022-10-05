import React, { ReactElement } from "react";
import { isGreenLine, isRapidTransit } from "../../models/route";
import { EnhancedRoute } from "../../__v3api";
import DefaultHoursOfOperation from "./DefaultHoursOfOperation";
import GreenLineScheduleLinks from "./GreenLineScheduleLinks";
import RapidTransitHoursOfOperation from "./RapidTransitHoursOfOperation";
import { SchedulePDF } from "./__schedule";

const HoursOfOperation = ({
  route,
  pdfs,
  hours
}: {
  route: EnhancedRoute;
  pdfs: SchedulePDF[];
  hours: string;
}): ReactElement<HTMLElement> | null => {
  // if (isGreenLine(route)) {
  //   return <GreenLineScheduleLinks pdfs={pdfs}/>
  // } else if (isRapidTransit(route)) {
  //   return <RapidTransitHoursOfOperation pdfs={pdfs} route={route}/>
  // } else {
  //   return <DefaultHoursOfOperation hours={hours}/>
  // }
  return <RapidTransitHoursOfOperation pdfs={pdfs} route={route} />;
};

export default HoursOfOperation;
