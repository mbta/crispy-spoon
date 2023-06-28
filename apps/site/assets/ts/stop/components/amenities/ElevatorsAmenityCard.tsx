import React from "react";
import AmenityCard, { AmenityModal } from "./AmenityCard";
import { elevatorIcon } from "../../../helpers/icon";
import { Alert, Facility } from "../../../__v3api";
import Alerts from "../../../components/Alerts";
import { hasFacilityAlert } from "../../../models/alert";

const ElevatorsAmenityCard = ({
  stopName,
  alerts,
  facilities
}: {
  stopName: string;
  alerts: Alert[];
  facilities: Facility[] | undefined;
}): JSX.Element => {
  const icon = (
    <span className="m-stop-page__icon">{elevatorIcon("c-svg__icon")}</span>
  );

  const hasFacilities = facilities ? facilities.length > 0 : false;

  return (
    <AmenityCard headerText="Elevators" icon={icon}>
      modalContent=
      {hasFacilities && (
        <AmenityModal headerText={`Elevators at ${stopName}`}>
          <Alerts alerts={alerts} />
          <h2 className="h3">Eleavator Status</h2>
          {/* loop over facilities and render circle and icon on status based on if facility has alert */}

          <div className="elevator-row facilities-list-header">
            <h3>Elevator</h3>
            <h3>Status</h3>
          </div>

          <div className="facilities-list">
            {facilities?.map(facility => {
              return (
                <div className="elevator-row elevator-text">
                  <div className="elevator-name">
                    {facility.attributes.short_name}
                  </div>
                  {hasFacilityAlert(facility.id, alerts) ? (
                    <div>
                      <i className="fa-solid fa-circle amenity-status amenity-out"></i>
                      Out of Order
                    </div>
                  ) : (
                    <div>
                      <i className="fa-solid fa-circle amenity-status amenity-working"></i>
                      Working
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          <a className="c-call-to-action" href="/accessibility/trip-planning">
            Plan an accessible trip
          </a>
          <br />
          <a className="c-call-to-action" href="/customer-support">
            Report an elevator issue
          </a>
        </AmenityModal>
      )}
    </AmenityCard>
  );
};

export default ElevatorsAmenityCard;
