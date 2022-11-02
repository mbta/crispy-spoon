import { times } from "lodash";
import React, { ReactElement, useContext, useState } from "react";
import ExpandableBlock from "../../../components/ExpandableBlock";
import { routeToModeName } from "../../../helpers/css";
import { stopForId } from "../../../helpers/stop-tree";
import { Alert } from "../../../__v3api";
import { RouteStop, StopId, StopTree } from "../__schedule";
import {
  BRANCH_LINE_WIDTH,
  CIRC_DIAMETER,
  CIRC_RADIUS
} from "./graphics/graphic-helpers";
import { branchPosition, diagramWidth } from "./line-diagram-helpers";
import { StopRefContext } from "./TreeLineDiagramWithStops";
import TreeStopCard from "./TreeStopCard";
import { LiveDataByStop } from "./__line-diagram";

interface Props {
  stopTree: StopTree;
  stopIds: StopId[];
  alerts: Alert[];
  handleStopClick: (stop: RouteStop) => void;
  liveData?: LiveDataByStop;
}

const BranchToggle = (
  stopTree: StopTree,
  stopIds: StopId[],
  isExpanded: boolean
): JSX.Element => {
  const position = branchPosition(stopTree, stopIds[0]);
  const width = diagramWidth(position) - 15;

  return (
    <div className="m-schedule-diagram__expander-header">
      <div style={{ width }}>
        {!isExpanded && (
          <svg
            className={`line-diagram-svg__toggle ${routeToModeName(
              stopForId(stopTree, stopIds[0]).route!
            )}`}
            width={width}
            height="100%"
          >
            <g
              transform={`translate(${(position - 1) * BRANCH_LINE_WIDTH -
                1}, 1)`}
            >
              <rect width={CIRC_DIAMETER * 2} height="42" rx={CIRC_DIAMETER} />
              {times(3, i => (
                <circle
                  key={i}
                  cx={CIRC_DIAMETER}
                  cy={10 * (i + 1) + 1}
                  r={CIRC_RADIUS}
                />
              ))}
            </g>
          </svg>
        )}
      </div>
      <button className="btn btn-link m-schedule-diagram__toggle" type="button">
        {stopIds.length} stops
      </button>
    </div>
  );
};

const TreeExpandableBranch = ({
  stopTree,
  stopIds,
  alerts,
  handleStopClick,
  liveData
}: Props): ReactElement<HTMLElement> => {
  const [isExpanded, setIsExpanded] = useState(false);
  const updateAllStopCoords = useContext(StopRefContext)[1];
  // reset all the coordinates.
  React.useEffect(() => {
    updateAllStopCoords();
  }, [isExpanded, updateAllStopCoords]);

  return (
    <div className="m-schedule-diagram__expander">
      <ExpandableBlock
        header={{
          iconSvgText: null,
          text: BranchToggle(stopTree, stopIds, isExpanded)
        }}
        initiallyExpanded={isExpanded}
        notifyExpanded={(blockIsExpanded: boolean) => {
          setIsExpanded(blockIsExpanded);
        }}
        preventScroll
        id={`${stopForId(stopTree, stopIds[0]).branch}`}
      >
        <>
          {stopIds.map(stopId => (
            <TreeStopCard
              key={stopId}
              stopTree={stopTree}
              stopId={stopId}
              alerts={alerts}
              onClick={handleStopClick}
              liveData={liveData?.[stopId]}
            />
          ))}
        </>
      </ExpandableBlock>
    </div>
  );
};

export default TreeExpandableBranch;
