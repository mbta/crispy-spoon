import React, { FormEvent, ReactElement, useState } from "react";
import { DirectionId, DirectionInfo, Route } from "../../../__v3api";
import { SimpleStopMap, SelectedOrigin } from "../__schedule";
import SelectContainer from "./SelectContainer";

const validDirections = (directionInfo: DirectionInfo): DirectionId[] =>
  ([0, 1] as DirectionId[]).filter(dir => directionInfo[dir] !== null);

interface Props {
  onDirectionChange: (direction: DirectionId) => void;
  onOriginChange: (origin: SelectedOrigin) => void;
  onOriginSelectClick: () => void;
  onSubmit?: () => void;
  route: Route;
  selectedDirection: DirectionId;
  selectedOrigin: SelectedOrigin;
  stopsByDirection: SimpleStopMap;
}

export default ({
  onDirectionChange,
  onOriginChange,
  onSubmit = () => {},
  onOriginSelectClick,
  route,
  selectedDirection,
  selectedOrigin,
  stopsByDirection
}: Props): ReactElement => {
  const {
    direction_names: directionNames,
    direction_destinations: directionDestinations
  } = route;

  const [originError, setOriginError] = useState(false);

  const handleOriginClick = (): void => {
    setOriginError(false);
    onOriginSelectClick();
  };

  const handleSubmit = (event: FormEvent): void => {
    event.preventDefault();

    if (!selectedOrigin) {
      setOriginError(true);
    } else {
      setOriginError(false);
      onSubmit();
    }
  };

  const directionNameForId = (
    direction: DirectionId
  ): string => `${directionNames[direction]!.toUpperCase()}
  ${directionDestinations[direction]!}`;

  return (
    <form onSubmit={handleSubmit}>
      <h2>Schedule Finder</h2>

      <div className="schedule-finder__prompt">
        {`Get schedule information for your next ${route.name} trip.`}
      </div>

      {originError && (
        <div className="error-container">
          <span role="alert">Please provide an origin</span>
        </div>
      )}

      <div className="schedule-finder__inputs">
        <label className="schedule-finder__label">
          Choose a direction
          <SelectContainer>
            <select
              className="c-select-custom"
              value={selectedDirection}
              onChange={e =>
                onDirectionChange(parseInt(e.target.value, 10) as DirectionId)
              }
            >
              {validDirections(directionNames).map(direction => (
                <option
                  key={direction}
                  value={direction}
                  aria-label={directionNameForId(direction)}
                >
                  {directionNameForId(direction)}
                </option>
              ))}
            </select>
          </SelectContainer>
        </label>

        <label className="schedule-finder__label">
          Choose an origin stop
          <SelectContainer error={originError} handleClick={handleOriginClick}>
            <select
              className="c-select-custom c-select-custom--noclick"
              value={selectedOrigin || ""}
              onChange={e => onOriginChange(e.target.value || null)}
            >
              <option value="">Select</option>
              {stopsByDirection[selectedDirection].map(({ id, name }) => (
                <option key={id} value={id} aria-label={name}>
                  {name}
                </option>
              ))}
            </select>
          </SelectContainer>
        </label>
      </div>

      <div className="schedule-finder__submit text-right">
        <input
          className="btn btn-primary"
          type="submit"
          value="Get schedules"
        />
      </div>
    </form>
  );
};
