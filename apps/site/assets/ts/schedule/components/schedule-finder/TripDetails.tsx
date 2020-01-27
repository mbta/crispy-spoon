import React, { ReactElement } from "react";
import TripStop from "./TripStop";
import { TripInfo } from "../__trips";

export interface State {
  data: TripInfo | null;
  isLoading: boolean;
  error: boolean;
}

interface Props {
  state: State;
  showFare: boolean;
}

const TripSummary = ({
  tripInfo
}: {
  tripInfo: TripInfo;
}): ReactElement<HTMLElement> => (
  <tr>
    <td colSpan={3}>
      <div className="schedule-table__subtable-trip-info">
        <div className="schedule-table__subtable-trip-info-title u-small-caps u-bold">
          Trip length
        </div>
        {tripInfo.times.length} stops, {tripInfo.duration} minutes total
      </div>
      <div className="schedule-table__subtable-trip-info">
        <div className="schedule-table__subtable-trip-info-title u-small-caps u-bold">
          Fare
        </div>
        {tripInfo.fare && tripInfo.fare.price}
        <a
          className="schedule-table__subtable-trip-info-link"
          href={tripInfo.fare.fare_link}
        >
          View fares
        </a>
      </div>
    </td>
  </tr>
);

const allTimesHaveSchedule = (tripInfo: TripInfo): boolean =>
  tripInfo.times.every(time => !!time.schedule);

export const TripDetails = ({
  state,
  showFare
}: Props): ReactElement<HTMLElement> | null => {
  const { data: tripInfo, error, isLoading } = state;

  if (isLoading) {
    return (
      <div className="c-spinner__container">
        <div className="c-spinner">Loading...</div>
      </div>
    );
  }

  const errorLoadingTrip = (
    <p>
      <em>Error loading trip details. Please try again later.</em>
    </p>
  );

  if (error) {
    return errorLoadingTrip;
  }

  if (!tripInfo) return null;

  return (
    <table className="schedule-table__subtable">
      <thead>
        <TripSummary tripInfo={tripInfo} />
        <tr>
          <th scope="col" className="schedule-table__subtable-data">
            Stops
          </th>
          {showFare && (
            <th
              scope="col"
              className="schedule-table__subtable-data schedule-table__subtable-data--right-adjusted"
            >
              Fare
            </th>
          )}
          <th
            scope="col"
            className="schedule-table__subtable-data schedule-table__subtable-data--right-adjusted"
          >
            Arrival
          </th>
        </tr>
      </thead>
      <tbody className="schedule-table__subtable-tbody">
        {allTimesHaveSchedule(tripInfo)
          ? tripInfo.times.map((departure, index: number) => (
              <TripStop
                departure={departure}
                index={index}
                showFare={showFare}
                routeType={tripInfo.route_type}
                key={departure.schedule.stop.id}
              />
            ))
          : errorLoadingTrip}
      </tbody>
    </table>
  );
};
