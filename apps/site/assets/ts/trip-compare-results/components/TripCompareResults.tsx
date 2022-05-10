import React, { ReactElement, useState } from "react";
import { handleReactEnterKeyPress } from "../../helpers/keyboard-events";
import TripPlannerResults, { Itinerary } from "./TripPlannerResults";

interface Props {
  // eslint-disable-next-line
  itineraryData: Itinerary[];
  itineraryHeader: string;
}

const TripCompareResults = ({
  itineraryData,
  itineraryHeader
}: Props): ReactElement<HTMLElement> => {
  const [source, setSource] = useState("NEW");

  const filteredData = itineraryData.filter(i => i.source === source);
  const classRedesigned =
    source !== "NEW"
      ? "m-alerts__mode-button"
      : "m-alerts__mode-button m-alerts__mode-button--selected";
  const classCurrent =
    source === "NEW"
      ? "m-alerts__mode-button"
      : "m-alerts__mode-button m-alerts__mode-button--selected";

  const onClickNew = (): void => setSource("NEW");
  const onClickCurrent = (): void => setSource("CURRENT");

  return (
    <>
      <div>
        <div className="m-alerts__mode-buttons">
          <div className="m-alerts__mode-button-container">
            <div
              className={classRedesigned}
              onClick={onClickNew}
              onKeyPress={e => handleReactEnterKeyPress(e, onClickNew)}
              role="button"
              tabIndex={0}
            >
              <div className="m-alerts__mode-button-name">Redesigned</div>
            </div>
          </div>
          <div className="m-alerts__mode-button-container">
            <div
              className={classCurrent}
              onClick={onClickCurrent}
              onKeyPress={e => handleReactEnterKeyPress(e, onClickCurrent)}
              role="button"
              tabIndex={0}
            >
              <div className="m-alerts__mode-button-name">Current</div>
            </div>
          </div>
        </div>
        <p className="no-trips page-section">
          We found {filteredData.length} trips for you
        </p>
        <p className="instructions page-section">{itineraryHeader}</p>
        <p className="instructions page-section">
          <b>Note:</b> the following trips only reflect normal service (i.e. do
          not reflect current service, does not include service alert info)
        </p>
        <TripPlannerResults itineraryData={filteredData} />
      </div>
    </>
  );
};

export default TripCompareResults;
