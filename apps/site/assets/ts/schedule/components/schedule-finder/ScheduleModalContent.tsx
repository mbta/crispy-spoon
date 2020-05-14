import React, { ReactElement, useReducer, useEffect } from "react";
import UpcomingDepartures from "./UpcomingDepartures";
import { DirectionId, Route } from "../../../__v3api";
import {
  SimpleStopMap,
  StopPrediction,
  RoutePatternsByDirection,
  ServiceInSelector,
  ScheduleNote as ScheduleNoteType,
  SelectedOrigin,
  UserInput
} from "../__schedule";
import { reducer } from "../../../helpers/fetch";
import ScheduleFinderForm from "./ScheduleFinderForm";
import ServiceSelector from "./ServiceSelector";
import ScheduleNote from "../ScheduleNote";
import { isInCurrentService } from "../../../helpers/service";
import { formattedDate } from "../../../helpers/date";

interface Props {
  handleChangeDirection: (direction: DirectionId) => void;
  handleChangeOrigin: (origin: SelectedOrigin) => void;
  handleOriginSelectClick: () => void;
  route: Route;
  selectedDirection: DirectionId;
  selectedOrigin: string;
  selectedDestination: string;
  services: ServiceInSelector[];
  stops: SimpleStopMap;
  routePatternsByDirection: RoutePatternsByDirection;
  today: string;
  scheduleNote: ScheduleNoteType | null;
}

type fetchAction =
  | { type: "FETCH_COMPLETE"; payload: StopPrediction[] }
  | { type: "FETCH_ERROR" }
  | { type: "FETCH_STARTED" };

export const fetchData = (
  routeId: string,
  selectedOrigin: string,
  selectedDirection: DirectionId,
  dispatch: (action: fetchAction) => void
): Promise<void> => {
  dispatch({ type: "FETCH_STARTED" });
  return (
    window.fetch &&
    window
      .fetch(
        `/schedules/finder_api/departures?id=${routeId}&stop=${selectedOrigin}&direction=${selectedDirection}`
      )
      .then(response => {
        if (response.ok) return response.json();
        throw new Error(response.statusText);
      })
      .then(json => dispatch({ type: "FETCH_COMPLETE", payload: json }))
      // @ts-ignore
      .catch(() => dispatch({ type: "FETCH_ERROR" }))
  );
};

const ScheduleModalContent = ({
  handleChangeDirection,
  handleChangeOrigin,
  handleOriginSelectClick,
  route,
  selectedDirection,
  selectedOrigin,
  selectedDestination,
  services,
  stops,
  routePatternsByDirection,
  today,
  scheduleNote
}: Props): ReactElement<HTMLElement> | null => {
  const { id: routeId } = route;

  const [state, dispatch] = useReducer(reducer, {
    data: null,
    isLoading: true,
    error: false
  });

  useEffect(
    () => {
      if (
        routeId !== undefined &&
        selectedOrigin !== undefined &&
        selectedDirection !== undefined
      ) {
        fetchData(routeId, selectedOrigin, selectedDirection, dispatch);
      }
    },
    [routeId, selectedDirection, selectedOrigin]
  );

  const serviceToday = services.some(service =>
    isInCurrentService(service, new Date(today))
  );

  const input: UserInput = {
    route: routeId,
    origin: selectedOrigin,
    date: today,
    direction: selectedDirection
  };

  return (
    <>
      <div className="schedule-finder schedule-finder--modal">
        <ScheduleFinderForm
          onDirectionChange={handleChangeDirection}
          onOriginChange={handleChangeOrigin}
          onOriginSelectClick={handleOriginSelectClick}
          route={route}
          selectedDirection={selectedDirection}
          selectedOrigin={selectedOrigin}
          stopsByDirection={stops}
        />
      </div>

      {serviceToday ? (
        <UpcomingDepartures state={state} input={input} />
      ) : (
        <div className="callout text-center u-bold">
          There are no scheduled trips for {formattedDate(today)}.
        </div>
      )}

      {scheduleNote ? (
        <ScheduleNote
          className="m-schedule-page__schedule-notes--modal"
          scheduleNote={scheduleNote}
        />
      ) : (
        <ServiceSelector
          stopId={selectedOrigin}
          services={services}
          routeId={routeId}
          directionId={selectedDirection}
          routePatterns={routePatternsByDirection[selectedDirection]}
          today={today}
          destinationStopId={selectedDestination}
          stops={stops}
        />
      )}
    </>
  );
};

export default ScheduleModalContent;
