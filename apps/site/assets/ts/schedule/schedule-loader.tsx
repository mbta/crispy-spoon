import React from "react";
import ReactDOM from "react-dom";
import SchedulePage from "./components/SchedulePage";
import ScheduleNote from "./components/ScheduleNote";
import Map from "./components/Map";
import { SchedulePageData } from "./components/__schedule";
import { MapData } from "../leaflet/components/__mapdata";

const render = (): void => {
  const mapDataEl = document.getElementById("js-map-data");
  if (!mapDataEl) return;
  const channel = mapDataEl.getAttribute("data-channel-id");
  if (!channel) throw new Error("data-channel-id attribute not set");
  const mapEl = document.getElementById("map-root");
  if (!mapEl) throw new Error("cannot find #map-root");
  const mapData: MapData = JSON.parse(mapDataEl.innerHTML);
  ReactDOM.render(<Map data={mapData} channel={channel} />, mapEl);

  const schedulePageDataEl = document.getElementById("js-schedule-page-data");
  if (!schedulePageDataEl) return;
  const schedulePageData = JSON.parse(
    schedulePageDataEl.innerHTML
  ) as SchedulePageData;
  ReactDOM.render(
    <SchedulePage schedulePageData={schedulePageData} />,
    document.getElementById("react-root")
  );

  if (schedulePageData.schedule_note) {
    ReactDOM.render(
      <ScheduleNote
        className="m-schedule-page__schedule-notes--mobile"
        scheduleNote={schedulePageData.schedule_note}
      />,
      document.getElementById("react-schedule-note-root")
    );
  }
};

export const onLoad = (): void => {
  render();
};

export default onLoad;
