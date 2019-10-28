import React, { useState, ReactElement } from "react";
import { ScheduleWithFare, ScheduleInfo } from "../__schedule";
import { RoutePillSmall } from "./UpcomingDepartures";
import { modeIcon, caret } from "../../../helpers/icon";
import { handleReactEnterKeyPress } from "../../../helpers/keyboard-events";
import { breakTextAtSlash } from "../../../helpers/text";

const totalMinutes = (schedules: ScheduleInfo): string => schedules.duration;

interface TableRowProps {
  schedules: ScheduleWithFare[];
}

interface BusTableRowProps extends TableRowProps {
  anySchoolTrips: boolean;
  isSchoolTrip: boolean;
}
interface Props {
  trip: ScheduleInfo;
  isSchoolTrip: boolean;
  anySchoolTrips: boolean;
}

interface AccordionProps {
  trip: ScheduleInfo;
  contentCallback: () => ReactElement<HTMLElement>;
}

const TripInfo = ({
  schedules
}: {
  schedules: ScheduleInfo;
}): ReactElement<HTMLElement> => {
  const lastTrip = schedules.schedules[schedules.schedules.length - 1];
  return (
    <tr>
      <td colSpan={3}>
        <div className="schedule-table__subtable-trip-info">
          <div className="schedule-table__subtable-trip-info-title u-small-caps u-bold">
            Trip length
          </div>
          {schedules.schedules.length} stops, {totalMinutes(schedules)} minutes
          total
        </div>
        <div className="schedule-table__subtable-trip-info">
          <div className="schedule-table__subtable-trip-info-title u-small-caps u-bold">
            Fare
          </div>
          {lastTrip.price}
          <a
            className="schedule-table__subtable-trip-info-link"
            href={lastTrip.fare_link}
          >
            View fares
          </a>
        </div>
      </td>
    </tr>
  );
};

export const Accordion = ({
  trip,
  contentCallback
}: AccordionProps): ReactElement<HTMLElement> => {
  const [expanded, setExpanded] = useState(false);
  const firstSchedule = trip.schedules[0];
  const mode = firstSchedule.route.type;
  const onClick = (): void => setExpanded(!expanded);

  return (
    <>
      <tr
        className={
          expanded ? "schedule-table__row-selected" : "schedule-table__row"
        }
        aria-controls={`trip-${firstSchedule.trip.id}`}
        aria-expanded={expanded}
        role="button"
        onClick={onClick}
        onKeyPress={e => handleReactEnterKeyPress(e, onClick)}
        tabIndex={0}
      >
        {contentCallback()}

        <td className="schedule-table__td schedule-table__td--flex-end">
          {caret(
            `c-expandable-block__header-caret${expanded ? "--white" : ""}`,
            expanded
          )}
        </td>
      </tr>
      {expanded && (
        <tr
          id={`trip-${firstSchedule.trip.id}`}
          className="schedule-table__subtable-container"
        >
          <td className="schedule-table__subtable-td">
            <table className="schedule-table__subtable">
              <thead>
                <TripInfo schedules={trip} />
                <tr className="schedule-table__subtable-row">
                  <th
                    scope="col"
                    className="schedule-table__subtable-data schedule-table__subtable-data--long"
                  >
                    Stops
                  </th>
                  {mode !== 3 && (
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
                {trip.schedules.map(
                  (schedule: ScheduleWithFare, index: number) => (
                    <tr
                      key={`${schedule.stop.id}-${schedule.trip.id}`}
                      className="schedule-table__subtable-row"
                    >
                      <td className="schedule-table__subtable-data">
                        <a href={`/stops/${schedule.stop.id}`}>
                          {breakTextAtSlash(schedule.stop.name)}
                        </a>
                      </td>
                      {mode !== 3 && (
                        <td className="schedule-table__subtable-data schedule-table__subtable-data--right-adjusted">
                          {index === 0 ? "" : schedule.price}
                        </td>
                      )}
                      <td className="schedule-table__subtable-data schedule-table__subtable-data--right-adjusted">
                        {schedule.time}
                      </td>
                    </tr>
                  )
                )}
              </tbody>
            </table>
          </td>
        </tr>
      )}
    </>
  );
};

const BusTableRow = ({
  schedules,
  anySchoolTrips,
  isSchoolTrip
}: BusTableRowProps): ReactElement<HTMLElement> => {
  const firstSchedule = schedules[0];

  return (
    <>
      {anySchoolTrips && (
        <td className="schedule-table__td--tiny">
          {isSchoolTrip && <strong>S</strong>}
        </td>
      )}
      <td className="schedule-table__td schedule-table__time">
        {firstSchedule.time}
      </td>
      <td className="schedule-table__td">
        <div className="schedule-table__row-route">
          <RoutePillSmall route={firstSchedule.route} />
        </div>
        {breakTextAtSlash(firstSchedule.trip.headsign)}
      </td>
    </>
  );
};

const DefaultTableRow = ({
  schedules
}: TableRowProps): ReactElement<HTMLElement> => {
  const firstSchedule = schedules[0];

  return (
    <>
      <td className="schedule-table__td">
        <div className="schedule-table__time">{firstSchedule.time}</div>
      </td>
      {firstSchedule.trip.name && (
        <td className="schedule-table__td schedule-table__tab-num">
          {firstSchedule.trip.name}
        </td>
      )}
      <td className="schedule-table__headsign">
        {modeIcon(firstSchedule.route.id)}{" "}
        {breakTextAtSlash(firstSchedule.trip.headsign)}
      </td>
    </>
  );
};

const TableRow = ({
  trip,
  isSchoolTrip,
  anySchoolTrips
}: Props): ReactElement<HTMLElement> | null => {
  const callback =
    trip.schedules[0].route.type === 3
      ? () => (
          <BusTableRow
            schedules={trip.schedules}
            isSchoolTrip={isSchoolTrip}
            anySchoolTrips={anySchoolTrips}
          />
        )
      : () => <DefaultTableRow schedules={trip.schedules} />;

  return <Accordion trip={trip} contentCallback={callback} />;
};

export default TableRow;
