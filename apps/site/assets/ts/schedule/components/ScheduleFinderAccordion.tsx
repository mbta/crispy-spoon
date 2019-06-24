import React, { ReactElement } from "react";
import icon from "../../../static/images/icon-schedule-finder.svg";
import ExpandableBlock from "../../components/ExpandableBlock";
import ScheduleFinder from "./ScheduleFinder";
import { Route, DirectionId } from "../../__v3api";
import { SimpleStop } from "./__schedule";
interface Props {
  directionId: DirectionId;
  route: Route;
  stops: SimpleStop[];
}

const ScheduleFinderAccordion = ({
  directionId,
  route,
  stops
}: Props): ReactElement<HTMLDivElement> => (
  <div className="schedule-finder--mobile">
    <ExpandableBlock
      header={{ text: "Schedule Finder", iconSvgText: icon }}
      initiallyExpanded={false}
      id="schedule-finder-mobile"
      panelClassName="schedule-finder--accordion"
    >
      <ScheduleFinder
        directionId={directionId}
        hideHeader={true}
        route={route}
        stops={stops}
      />
    </ExpandableBlock>
  </div>
);

export default ScheduleFinderAccordion;
