import React, { ReactElement, useState } from "react";
import { SimpleStop, SelectedOrigin, SelectedDirection } from "../__schedule";
import OriginListItem from "./OriginListItem";
import { DirectionId } from "../../../__v3api";
import SearchBox from "../../../components/SearchBox";

const stopListSearchFilter = (
  stops: SimpleStop[],
  originSearch: string
): SimpleStop[] => {
  if (originSearch.trim() === "") {
    return stops;
  }

  const streetSuffixRegExp = /( s| st| | st\.| str| stre| stree| street)$/gi;
  const cleanSearch = originSearch.trim().replace(streetSuffixRegExp, "");

  const regExp = new RegExp(cleanSearch, "gi");
  return stops.filter(stop => (stop.name.match(regExp) || []).length > 0);
};

interface Props {
  selectedOrigin: SelectedOrigin;
  selectedDirection: SelectedDirection;
  stops: SimpleStop[];
  handleChangeOrigin: Function;
  directionId: DirectionId;
}

const OriginModalContent = ({
  selectedOrigin,
  stops,
  handleChangeOrigin
}: Props): ReactElement<HTMLElement> => {
  const [originSearch, setOriginSearch] = useState("");

  return (
    <>
      <br />
      <p className="schedule-finder__origin-text">
        <strong>Choose an origin stop</strong>
      </p>
      <SearchBox
        id="origin-filter"
        labelText="Choose an origin stop"
        className="schedule-finder__origin-search-container"
        placeholder="Filter stops and stations"
        onChange={setOriginSearch}
      />
      <p className="schedule-finder__origin-text">
        Select from the list below.
      </p>
      <div className="schedule-finder__origin-list">
        {stopListSearchFilter(stops, originSearch).map((stop: SimpleStop) => (
          <OriginListItem
            key={stop.id}
            stop={stop}
            changeOrigin={handleChangeOrigin}
            selectedOrigin={selectedOrigin}
            lastStop={stops[stops.length - 1]}
          />
        ))}
      </div>
    </>
  );
};

export default OriginModalContent;
