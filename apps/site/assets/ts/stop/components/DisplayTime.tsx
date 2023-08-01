/**
 * <DisplayTime /> Renders a UI element composing several different aspects of a
 * "departure" time. The following diagrams depict the layout used for the list
 * on the realtime tracking page, but can be further adjusted with CSS.
 *
  |------------|---------------------------------------------------------|
  | maybe Icon | {maybe "Delayed"} Time1 maybe Time2                     |
  |------------|---------------------------------------------------------|
  |            | {maybe "Delayed"} {maybe Delayed Details} maybe Details |
  |------------|---------------------------------------------------------|

  Example uses:
  |------|-----------|    |------|---------|
  |      | 12:59 AM  |    | Icon | 20 min  |
  |------|-----------|    |------|---------|
  |      | Tomorrow  |
  |------|-----------|

  |------|------------------- |    |------|-----------------------------|
  | Icon | Delayed 4:24PM     |    | Icon | 28 min                      |
  |------|--------------------|    |------|-----------------------------|
  |      | ~~4:15PM~~ Track 3 |    |      | Delayed 11:14AM ~~11:05AM~~ |
  |------|--------------------|    |------|-----------------------------|
 */

import React, { ReactElement } from "react";
import { isTomorrow } from "date-fns";
import { DepartureInfo } from "../../models/departureInfo";
import realtimeIcon from "../../../static/images/icon-realtime-tracking.svg";
import SVGIcon from "../../helpers/render-svg";
import {
  departureInfoToTime,
  displayInfoContainsPrediction
} from "../../helpers/departureInfo";
import BasicTime from "./BasicTime";

interface DisplayTimeProps {
  departure: DepartureInfo;
  isCR: boolean;
  targetDate?: Date | undefined;
}

/**
 * Renders a UI element composing several different aspects of a "departure"
 * time.
 *  - An icon that displays when there's a prediction present
 *  - A "countdown" that shows the predicted or scheduled time
 *  - Additional text with secondary information
 *
 * This component sets up and uses a context provider to selectively share
 * departure details with the relatively complex inner elements.
 */
const DisplayTime = ({
  departure,
  isCR,
  targetDate
}: DisplayTimeProps): ReactElement<HTMLElement> | null => {
  const { isCancelled, isDelayed, routeMode, schedule, prediction } = departure;
  const isDelayedAndDisplayed = isDelayed && routeMode !== "subway";
  const time = departureInfoToTime(departure);
  const track = prediction?.track;
  const trackName = isCR && !!track && `Track ${track}`;
  const tomorrow = !!time && isTomorrow(time);

  return (
    <>
      <div>
        {displayInfoContainsPrediction(departure) &&
          !isCancelled &&
          SVGIcon("c-svg__icon--realtime fs-10", realtimeIcon)}
      </div>
      {isCancelled && schedule ? (
        <div className="fs-14">
          Cancelled{" "}
          <BasicTime
            displayType="absolute"
            time={schedule.time}
            targetDate={targetDate}
            strikethrough
          />
        </div>
      ) : (
        <>
          <div className="stop-routes__departures-time">
            <BasicTime
              displayType={isCR ? "absolute" : "relative"}
              time={time}
              targetDate={targetDate}
            />
          </div>
          <div className="stop-routes__departures-details fs-14">
            {isDelayedAndDisplayed && schedule && (
              <>
                Delayed{" "}
                <BasicTime
                  displayType="absolute"
                  time={schedule.time}
                  targetDate={targetDate}
                  strikethrough
                />
              </>
            )}{" "}
            {/* Prioritize displaying Tomorrow over track name if both are present */}
            {tomorrow ? "Tomorrow" : trackName || null}
          </div>
        </>
      )}
    </>
  );
};

export { DisplayTime as default };
