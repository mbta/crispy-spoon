import React, { ReactElement } from "react";
import { Provider } from "react-redux";
import { updateInLocation } from "use-query-params";
import useFilteredList from "../../../hooks/useFilteredList";
import SearchBox from "../../../components/SearchBox";
import { LineDiagramStop, SelectedOrigin, RouteStop } from "../__schedule";
import { DirectionId, Route } from "../../../__v3api";
import { createLineDiagramCoordStore } from "./graphics/graphic-helpers";
import StopCard from "./StopCard";
import LineDiagramWithStops from "./LineDiagramWithStops";
import { getCurrentState, storeHandler } from "../../store/ScheduleStore";
import { changeOrigin } from "../ScheduleLoader";
import useRealtime from "../../../hooks/useRealtime";
import currentLineSuspensions from "../../../helpers/line-suspensions";

interface LineDiagramProps {
  lineDiagram: LineDiagramStop[];
  route: Route;
  directionId: DirectionId;
}

const stationsOrStops = (routeType: number): string =>
  [0, 1, 2].includes(routeType) ? "Stations" : "Stops";

const LineDiagramAndStopListPage = ({
  lineDiagram,
  route,
  directionId
}: LineDiagramProps): ReactElement<HTMLElement> | null => {
  const { lineIsSuspended } = currentLineSuspensions(route.id);
  // also track the location of text to align the diagram points to
  const lineDiagramCoordStore = createLineDiagramCoordStore(lineDiagram);

  const updateURL = (origin: SelectedOrigin, direction?: DirectionId): void => {
    if (window) {
      // eslint-disable-next-line camelcase
      const newQuery = {
        "schedule_finder[direction_id]":
          direction !== undefined ? direction.toString() : "",
        "schedule_finder[origin]": origin
      };
      const newLoc = updateInLocation(newQuery, window.location);
      // newLoc is not a true Location, so toString doesn't work
      window.history.replaceState({}, "", `${newLoc.pathname}${newLoc.search}`);
    }
  };

  const handleStopClick = (stop: RouteStop): void => {
    changeOrigin(stop.id);

    const currentState = getCurrentState();
    const { modalOpen: modalIsOpen } = currentState;

    updateURL(stop.id, directionId);

    if (currentState.selectedOrigin !== undefined && !modalIsOpen) {
      storeHandler({
        type: "OPEN_MODAL",
        newStoreValues: {
          modalMode: "schedule"
        }
      });
    }
  };

  /**
   * Provide a search box for filtering stops
   */
  const [stopQuery, setStopQuery, filteredStops] = useFilteredList(
    lineDiagram,
    "route_stop.name"
  );

  const liveData = useRealtime(route, directionId, !lineIsSuspended);

  /**
   * Putting it all together
   */
  return (
    <>
      <h3 className="m-schedule-diagram__heading">
        {stationsOrStops(route.type)}
      </h3>
      {!lineIsSuspended ? (
        <SearchBox
          id="stop-search"
          labelText={`Search for a ${stationsOrStops(route.type)
            .toLowerCase()
            .slice(0, -1)}`}
          onChange={setStopQuery}
          className="m-schedule-diagram__filter"
        />
      ) : null}
      {stopQuery !== "" ? (
        <ol className="m-schedule-diagram m-schedule-diagram--searched">
          {filteredStops.length ? (
            (filteredStops as LineDiagramStop[]).map(
              (stop: LineDiagramStop) => (
                <StopCard
                  key={stop.route_stop.id}
                  stop={stop}
                  onClick={handleStopClick}
                  liveData={liveData ? liveData[stop.route_stop.id] : undefined}
                  searchQuery={stopQuery}
                />
              )
            )
          ) : (
            <div className="c-alert-item c-alert-item--low c-alert-item__top-text-container">
              No stops {route.direction_names[directionId]} to{" "}
              {route.direction_destinations[directionId]} matching{" "}
              <b className="u-highlight">{stopQuery}</b>. Try changing your
              direction or adjusting your search.
            </div>
          )}
        </ol>
      ) : (
        <Provider store={lineDiagramCoordStore}>
          <LineDiagramWithStops
            stops={lineDiagram}
            handleStopClick={handleStopClick}
            liveData={liveData}
          />
        </Provider>
      )}
    </>
  );
};

export default LineDiagramAndStopListPage;
