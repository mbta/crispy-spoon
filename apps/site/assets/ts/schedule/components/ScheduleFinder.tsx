import React, { ReactElement } from "react";
import { Route, DirectionId } from "../../__v3api";
import {
  SimpleStopMap,
  RoutePatternsByDirection,
  ServiceInSelector,
  ScheduleNote as ScheduleNoteType,
  SelectedOrigin
} from "./__schedule";
import ScheduleFinderForm from "./schedule-finder/ScheduleFinderForm";
import ScheduleFinderModal, {
  Mode as ModalMode
} from "./schedule-finder/ScheduleFinderModal";
import { getCurrentState, storeHandler } from "../store/ScheduleStore";
import { routeToModeName } from "../../helpers/css";
import useDirectionChangeEvent from "../../hooks/useDirectionChangeEvent";

interface Props {
  updateURL: (origin: SelectedOrigin, direction?: DirectionId) => void;
  services: ServiceInSelector[];
  directionId: DirectionId;
  route: Route;
  stops: SimpleStopMap;
  routePatternsByDirection: RoutePatternsByDirection;
  today: string;
  scheduleNote: ScheduleNoteType | null;
  changeDirection: (direction: DirectionId) => void;
  selectedOrigin: SelectedOrigin;
  changeOrigin: (origin: SelectedOrigin) => void;
  closeModal: () => void;
  modalMode: ModalMode;
  modalOpen: boolean;
}

const ScheduleFinder = ({
  updateURL,
  directionId,
  route,
  services,
  stops,
  routePatternsByDirection,
  today,
  scheduleNote,
  modalMode,
  selectedOrigin,
  changeDirection,
  changeOrigin,
  modalOpen,
  closeModal
}: Props): ReactElement<HTMLElement> => {
  const currentDirection = useDirectionChangeEvent(directionId);
  const openOriginModal = (): void => {
    const currentState = getCurrentState();
    const { modalOpen: modalIsOpen } = currentState;
    if (!modalIsOpen) {
      storeHandler({
        type: "OPEN_MODAL",
        newStoreValues: {
          modalMode: "origin"
        }
      });
    }
  };

  const openScheduleModal = (): void => {
    const currentState = getCurrentState();
    const { modalOpen: modalIsOpen } = currentState;
    if (selectedOrigin !== undefined && !modalIsOpen) {
      storeHandler({
        type: "OPEN_MODAL",
        newStoreValues: {
          modalMode: "schedule"
        }
      });
    }
  };

  const handleOriginSelectClick = (): void => {
    storeHandler({
      type: "OPEN_MODAL",
      newStoreValues: {
        modalMode: "origin"
      }
    });
  };

  const isFerryRoute = routeToModeName(route) === "ferry";

  return (
    <div
      className={`${
        isFerryRoute ? "schedule-finder-vertical" : "schedule-finder"
      }`}
    >
      <ScheduleFinderForm
        onDirectionChange={changeDirection}
        onOriginChange={changeOrigin}
        onOriginSelectClick={openOriginModal}
        onSubmit={openScheduleModal}
        route={route}
        selectedDirection={currentDirection}
        selectedOrigin={selectedOrigin}
        stopsByDirection={stops}
      />
      {modalOpen && (
        <ScheduleFinderModal
          closeModal={closeModal}
          directionChanged={changeDirection}
          initialMode={modalMode}
          initialDirection={currentDirection}
          initialOrigin={selectedOrigin}
          handleOriginSelectClick={handleOriginSelectClick}
          originChanged={changeOrigin}
          route={route}
          routePatternsByDirection={routePatternsByDirection}
          scheduleNote={scheduleNote}
          services={services}
          stops={stops}
          today={today}
          updateURL={updateURL}
        />
      )}
    </div>
  );
};

export default ScheduleFinder;
