import React, { ReactElement } from "react";
import {
  ScheduleNote as ScheduleNoteType,
  ServiceException
} from "./__schedule";
import scheduleIcon from "../../../static/images/icon-schedule-finder.svg";

const service = (serviceTime: string): ReactElement<HTMLElement> => (
  <p className="m-schedule-page__service-note-time" key={serviceTime}>
    Trains arrive every {serviceTime}
  </p>
);

const offPeak = (
  offpeak: string,
  exceptions: ServiceException[]
): ReactElement<HTMLElement> => {
  const except =
    exceptions.length > 0
      ? `except ${exceptions.map(e => e.type).join(", ")}`
      : "";
  return service(`${offpeak} ${except}`);
};

interface Props {
  scheduleNote: ScheduleNoteType;
  className: string;
}

const ScheduleNote = ({
  scheduleNote: {
    peak_service: peakService,
    offpeak_service: offpeakService,
    exceptions
  },
  className
}: Props): ReactElement<HTMLElement> => (
  <div className={`m-schedule-page__schedule-notes ${className}`}>
    <h3 className="m-schedule-page__schedule-note-title">
      <div
        className="m-schedule-page__schedule-note-icon"
        dangerouslySetInnerHTML={{ __html: scheduleIcon }} // eslint-disable-line react/no-danger
      />
      Schedule Note
    </h3>
    <div className="m-schedule-page__schedule-note">
      <h4 className="m-schedule-page__service">Peak Service</h4>
      <div className="m-schedule-page__service-subheading">
        Weekdays 7 AM - 9 AM, 4 PM - 6:30 PM
      </div>
      {service(peakService)}
    </div>
    <div className="m-schedule-page__schedule-note">
      <h4 className="m-schedule-page__service">Off Peak / Weekends</h4>
      {offPeak(offpeakService, exceptions)}
      {exceptions.map(exception =>
        service(`${exception.service} ${exception.type}`)
      )}
    </div>
  </div>
);

export default ScheduleNote;
