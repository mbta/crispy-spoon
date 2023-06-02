import { isValid, parseISO, add } from "date-fns";
import { isArray, mergeWith, reduce, some } from "lodash";
import { StopId } from "../schedule/components/__schedule";
import { Alert, TimePeriodPairs } from "../__v3api";

export const isHighSeverityOrHighPriority = ({
  priority,
  severity
}: Alert): boolean => priority === "high" || severity >= 7;

export const isDiversion = ({ effect }: Alert): boolean =>
  effect === "shuttle" ||
  effect === "stop_closure" ||
  effect === "station_closure" ||
  effect === "detour";

export const alertsByStop = (alerts: Alert[], stopId: StopId): Alert[] =>
  alerts.filter(
    ({ informed_entity: entities }: Alert): boolean =>
      !!entities.stop && entities.stop!.some((id: StopId) => id === stopId)
  );

const hasEffect = (alerts: Alert[], effect: string): boolean =>
  some(alerts, alert => alert.effect === effect);

export const hasSuspension = (alerts: Alert[]): boolean =>
  hasEffect(alerts, "suspension");

export const hasShuttleService = (alerts: Alert[]): boolean =>
  hasEffect(alerts, "shuttle");

export const hasDetour = (alerts: Alert[]): boolean =>
  hasEffect(alerts, "detour");

export const alertsWithStop = (alerts: Alert[]): Alert[] =>
  alerts.filter(
    ({ informed_entity: entites }: Alert): boolean => !!entites.stop
  );

export const routeWideAlerts = (alerts: Alert[]): Alert[] =>
  alerts.filter(({ informed_entity: { entities } }: Alert): boolean =>
    entities.some(entity => !entity.stop && !entity.trip)
  );

export const alertsByRoute = (alerts: Alert[]): { [key: string]: Alert[] } => {
  return reduce(
    alerts,
    (acc, alert) => {
      // create a map of every route id to the alert
      const explodedAlerts = reduce(
        alert.informed_entity.route,
        (innerAcc, routeId) => {
          return { ...innerAcc, [routeId]: [alert] };
        },
        {}
      );

      return mergeWith(acc, explodedAlerts, (objValue, srcValue) => {
        if (isArray(objValue)) {
          return objValue.concat(srcValue);
        }
        return srcValue;
      });
    },
    {}
  );
};

// This will only return alerts with direction id specified (aka affecting a single direction)
export const alertsByDirectionId = (
  alerts: Alert[]
): { [key: number]: Alert[] } => {
  return reduce(
    alerts,
    (acc, alert) => {
      const explodedAlerts = reduce(
        alert.informed_entity.direction_id,
        (innerAcc, directionId) => {
          // only include specified directions
          if (directionId !== null) {
            return { ...innerAcc, [directionId]: [alert] };
          }
          return innerAcc;
        },
        {}
      );

      return mergeWith(acc, explodedAlerts, (objValue, srcValue) => {
        if (isArray(objValue)) {
          return objValue.concat(srcValue);
        }
        return srcValue;
      });
    },
    {}
  );
};

export const alertsAffectingBothDirections = (alerts: Alert[]): Alert[] => {
  return alerts.filter(alert => {
    return (
      alert.informed_entity.direction_id === null ||
      alert.informed_entity.direction_id.length === 0 ||
      alert.informed_entity.direction_id[0] === null
    );
  });
};

export const uniqueByEffect = (
  alert: Alert,
  index: number,
  alerts: Alert[]
): boolean => alerts.findIndex(a => a.effect === alert.effect) === index;

const withLeadingZero = (n: string): string => `0${n}`.slice(-2);

const legacyDateParsing = (dateString: string): Date | null => {
  const datePattern = /^(\d{4})-(\d{1,2})-(\d{1,2})\s(\d{1,2}):(\d{2})$/;
  const match = datePattern.exec(dateString);
  if (match) {
    const [, year, rawMonth, rawDay, rawHour, min] = match;
    return new Date(
      `${year}-${withLeadingZero(rawMonth)}-${withLeadingZero(
        rawDay
      )}T${withLeadingZero(rawHour)}:${min}:00`
    );
  }
  return null;
};

const activePeriodToDates = (
  activePeriod: TimePeriodPairs
): (Date | null)[] => {
  return activePeriod.map((d: string): Date | null => {
    return isValid(d) ? parseISO(d) : legacyDateParsing(d);
  });
};

const isCurrentLifecycle = ({ lifecycle }: Alert): boolean =>
  lifecycle === "new" ||
  lifecycle === "ongoing" ||
  lifecycle === "ongoing_upcoming";

export const isBannerAlert = ({ effect }: Alert): boolean =>
  ["suspension", "stop_closure", "station_closure", "shuttle"].includes(effect);

export const isInNextXDays = (
  alert: Alert,
  days: number,
  currentDate: Date = new Date()
): boolean => {
  const xDays = add(Date.now(), { days });
  xDays.setHours(23, 59, 59); // set to end of X day
  if (!alert.active_period) return false;
  const dateRanges = alert.active_period.map(ap => activePeriodToDates(ap));
  const isInARange = dateRanges.some((range): boolean => {
    const [start, end] = range;
    if (!start || !isValid(start)) return false; // end might be null for ongoing alerts

    return (
      currentDate >= start &&
      // eslint-disable-next-line
      (end && isValid(end)
        ? days === 0
          ? currentDate <= end
          : currentDate <= xDays
        : true)
    );
  });
  return days === 0 ? isCurrentLifecycle(alert) && isInARange : isInARange;
};

export const isActiveDiversion = (alert: Alert): boolean =>
  isDiversion(alert) && isInNextXDays(alert, 0);

export const hasAnActiveDiversion = (
  stopId: StopId,
  alerts: Alert[]
): boolean => alertsByStop(alerts, stopId).some(isActiveDiversion);
