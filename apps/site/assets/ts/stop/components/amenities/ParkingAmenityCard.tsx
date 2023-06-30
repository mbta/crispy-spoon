import React from "react";
import { includes } from "lodash";
import AmenityCard, { AmenityModal } from "./AmenityCard";
import { parkingIcon } from "../../../helpers/icon";
import { Alert, Stop } from "../../../__v3api";
import { getExternalMapURI } from "../ExternalMapLink";
import Alerts from "../../../components/Alerts";

const getModalContent = (
  stop: Stop,
  alertsForParking: Alert[]
): JSX.Element => {
  return (
    <AmenityModal headerText={`Parking at ${stop.name}`}>
      <Alerts alerts={alertsForParking} />
      <div>
        {stop.parking_lots.map(
          (park): JSX.Element => {
            const mobileAppURL = park.payment.mobile_app?.url;
            const supportsMobileApp = includes(
              park.payment.methods,
              "Mobile App"
            );
            const supportsInvoice = includes(park.payment.methods, "Invoice");

            let externalMapURI = null;
            if (park.latitude && park.longitude) {
              externalMapURI = getExternalMapURI(park.latitude, park.longitude);
            }

            return (
              <div key={park.name}>
                <h2>{park.name}</h2>
                <h3>Parking Rates</h3>
                <ul>
                  <li>
                    <b>Daily:</b>
                    <span className="ps-8">{park.payment.daily_rate}</span>
                  </li>
                  <li>
                    <b>Monthly:</b>
                    <span className="ps-8">{park.payment.monthly_rate}</span>
                  </li>
                  <li>
                    <b>Overnight:</b>
                    <span className="ps-8">{park.capacity.overnight}</span>
                  </li>
                </ul>
                <h3>Facility Information</h3>
                <ul>
                  <li>{park.capacity.total} total parking spots</li>
                  <li>{park.capacity.accessible} accessible spots</li>
                </ul>
                {externalMapURI && (
                  <div>
                    <a href={externalMapURI} className="c-call-to-action">
                      Get directions to this parking facility
                    </a>
                  </div>
                )}

                {park.payment.methods.length > 0 && (
                  <>
                    <h2>Payment Methods</h2>
                    <ul>
                      {supportsMobileApp && mobileAppURL && (
                        <li>
                          <a href={mobileAppURL}>PayByPhone</a> (Location{" "}
                          {park.payment.mobile_app?.id}). Use the:
                          <ul>
                            <li>App</li>
                            <li>Website</li>
                            <li>Or call 866-234-7275</li>
                          </ul>
                        </li>
                      )}
                      {supportsInvoice && (
                        <li>Invoice in the mail ($1 surcharge)</li>
                      )}
                    </ul>
                  </>
                )}
              </div>
            );
          }
        )}
      </div>
      <div>
        <a href="/parking/pay-day" className="c-call-to-action">
          View more payment information
        </a>
      </div>
      <div>
        <a href="/parking" className="c-call-to-action">
          Learn more about parking at the T
        </a>
      </div>
    </AmenityModal>
  );
};

const ParkingAmenityCard = ({
  stop,
  alertsForParking
}: {
  stop: Stop;
  alertsForParking: Alert[];
}): JSX.Element => {
  const icon = <span className="m-stop-page__icon">{parkingIcon()}</span>;
  const modalContent = getModalContent(stop, alertsForParking);

  return (
    <AmenityCard headerText="Parking" icon={icon} modalContent={modalContent} />
  );
};

export default ParkingAmenityCard;
