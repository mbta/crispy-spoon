import { Route, Trip, Stop, PredictedOrScheduledTime } from "../../__v3api";

export interface Journey {
  trip: Trip;
  route: Route;
  departure: Departure;
}

export interface EnhancedJourney extends Journey {
  realtime: PredictedOrScheduledTime;
}

export interface Departure {
  time: string;
  schedule: Schedule | null;
  prediction: Prediction | null;
}

export interface TripDeparture {
  schedule: TripSchedule;
  prediction: Prediction | null;
}

export interface TripInfo {
  times: TripDeparture[];
  vehicle: Vehicle | null;
  vehicle_stop_name: string;
  stop_count: number;
  status: string;
  duration: number;
  fare: Fare;
}

export interface Prediction {
  delay: number;
  status: string | null;
  track: string | null;
}

export interface Schedule {
  time: string;
  stop_sequence: number;
  pickup_type: number;
  "flag?": boolean;
  "early_departure?": boolean;
  "last_stop?": boolean;
}

export interface TripSchedule extends Schedule {
  stop: Stop;
  fare: Fare;
}

export interface Vehicle {
  trip_id: string;
  stop_id: string;
  status: string;
}

export interface Fare {
  price: string;
  fare_link: string;
}
