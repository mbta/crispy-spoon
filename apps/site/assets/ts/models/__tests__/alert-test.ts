import { StopId } from "../../schedule/components/__schedule";
import { Alert, InformedEntitySet, TimePeriodPairs } from "../../__v3api";
import {
  isHighSeverityOrHighPriority,
  isInNextXDays,
  alertsByStop,
  uniqueByEffect,
  isDiversion,
  isActiveDiversion,
  hasAnActiveDiversion,
  alertsByRoute,
  alertsByDirectionId,
  alertsAffectingBothDirections
} from "../alert";
import { add } from "date-fns";

const zeroPadded = (num: number): string => `${num}`.padStart(2, "0");

const activePeriodDateFormatted = (ms: number): string => {
  const date = new Date(ms);
  return `${date.getFullYear()}-${zeroPadded(date.getMonth() + 1)}-${zeroPadded(
    date.getDate()
  )} ${zeroPadded(date.getHours())}:${zeroPadded(date.getMinutes())}`;
};

export const aroundNow = () => {
  const now = Date.now();
  const five_minutes = 300_000;
  return [
    [
      activePeriodDateFormatted(now - five_minutes),
      activePeriodDateFormatted(now + five_minutes)
    ] as TimePeriodPairs
  ];
};

export const beforeNow = () => {
  const now = Date.now();
  const five_minutes = 300_000;
  return [
    [
      activePeriodDateFormatted(now - 2 * five_minutes),
      activePeriodDateFormatted(now - five_minutes)
    ] as TimePeriodPairs
  ];
};

export const threeDaysFromNow = () => {
  const now = Date.now();
  const five_minutes = 300_000;
  return [
    [
      activePeriodDateFormatted(now - five_minutes),
      activePeriodDateFormatted(add(now, { days: 3 }).getMilliseconds())
    ] as TimePeriodPairs
  ];
};

const testDate = new Date("2020-09-10T09:00");
const alert1: Alert = {
  severity: 7,
  priority: "high",
  lifecycle: "new",
  active_period: [["2020-09-10 08:00", "2020-09-10 20:00"]]
} as Alert;
const alert2: Alert = {
  severity: 3,
  priority: "high",
  lifecycle: "ongoing",
  active_period: [["2020-09-08 12:00", "2020-09-11 20:00"]]
} as Alert;
const alert3: Alert = {
  severity: 7,
  priority: "low",
  lifecycle: "ongoing_upcoming",
  active_period: [["2020-09-10 12:00", "2020-09-10 20:00"]]
} as Alert;
const alert4: Alert = {
  severity: 3,
  priority: "low",
  lifecycle: "upcoming",
  active_period: [["2020-09-10 12:00", "2020-09-10 20:00"]]
} as Alert;
const alert5: Alert = {
  severity: 7,
  priority: "high",
  lifecycle: "ongoing",
  active_period: null as any
} as Alert;
const alert6: Alert = {
  severity: 7,
  priority: "high",
  lifecycle: "ongoing",
  active_period: [[null as any, "2020-09-10 20:00"]]
} as Alert;
const alert7: Alert = {
  severity: 7,
  priority: "high",
  lifecycle: "new",
  active_period: [["2020-09-10 08:00", null as any]]
} as Alert;
// Legacy Data format
const alert8: Alert = {
  severity: 7,
  priority: "high",
  lifecycle: "new",
  active_period: [["2020-5-9 13:52", null as any]]
} as Alert;

describe("isHighSeverityOrHighPriority", () => {
  test.each`
    alert     | isHigh
    ${alert1} | ${true}
    ${alert2} | ${true}
    ${alert3} | ${true}
    ${alert4} | ${false}
  `(
    "isHighSeverityOrHighPriority returns whether alert is high..",
    ({ alert, isHigh }) => {
      if (isHigh) {
        expect(isHighSeverityOrHighPriority(alert)).toBeTruthy();
      } else {
        expect(isHighSeverityOrHighPriority(alert)).toBeFalsy();
      }
    }
  );
});

describe("isDiversion", () => {
  test("returns whether effect is a diversion", () => {
    expect(isDiversion(alert1)).toBeFalsy();
    expect(isDiversion({ ...alert1, effect: "shuttle" })).toBeTruthy();
    expect(isDiversion({ ...alert1, effect: "stop_closure" })).toBeTruthy();
    expect(isDiversion({ ...alert1, effect: "station_closure" })).toBeTruthy();
    expect(isDiversion({ ...alert1, effect: "detour" })).toBeTruthy();
    expect(isDiversion({ ...alert1, effect: "other" })).toBeFalsy();
  });
});

describe("isInNextXDays", () => {
  test.each`
    alert     | isCurrent
    ${alert1} | ${true}
    ${alert2} | ${true}
    ${alert3} | ${false}
    ${alert4} | ${false}
    ${alert5} | ${false}
    ${alert6} | ${false}
    ${alert7} | ${true}
    ${alert8} | ${true}
  `(
    "isInNextXDays returns whether alert is current based on lifecycle and active period given days from now is 0",
    ({ alert, isCurrent }) => {
      if (isCurrent) {
        expect(isInNextXDays(alert, 0, testDate)).toBeTruthy();
      } else {
        expect(isInNextXDays(alert, 0, testDate)).toBeFalsy();
      }
    }
  );

  test("true if the alert is in the next 7 days", () => {
    const alert: Alert = {
      active_period: threeDaysFromNow(),
      lifecycle: "new",
      effect: "shuttle"
    } as Alert;

    expect(isInNextXDays(alert, 7)).toBeTruthy();
  });
});

describe("alertsByStop", () => {
  test("alertsByStop finds alerts affecting a certain stop", () => {
    const alert_two = {
      ...alert2,
      informed_entity: { stop: ["place-sstat"] } as InformedEntitySet
    };
    const alert_three = {
      ...alert3,
      informed_entity: { stop: ["place-sstat"] } as InformedEntitySet
    };
    const alerts = [
      { ...alert1, informed_entity: { stop: null } as InformedEntitySet },
      alert_two,
      alert_three,
      { ...alert4, informed_entity: { stop: null } as InformedEntitySet }
    ];
    const alertsForStop = alertsByStop(alerts, "place-sstat");
    expect(alertsForStop).toEqual([alert_two, alert_three]);
  });
});

describe("uniqueByEffect", () => {
  test("uniqueByEffect enables filtering to unique effects", () => {
    const alerts = [
      { effect: "shuttle" } as Alert,
      { effect: "detour" } as Alert,
      { effect: "detour" } as Alert,
      { effect: "shuttle" } as Alert,
      { effect: "unknown" } as Alert
    ];
    expect(alerts.filter(uniqueByEffect)).toHaveLength(3);
    expect(alerts.filter(uniqueByEffect).map(a => a.effect)).toEqual([
      "shuttle",
      "detour",
      "unknown"
    ]);
  });
});

describe("isActiveDiversion", () => {
  test("true if the alert is current and a diversion", () => {
    const alert: Alert = {
      active_period: aroundNow(),
      lifecycle: "new",
      effect: "shuttle"
    } as Alert;

    expect(isActiveDiversion(alert)).toBeTruthy();
  });

  test("false if not current", () => {
    const nonCurrentLifecyleAlert: Alert = {
      active_period: aroundNow(),
      lifecycle: "upcoming",
      effect: "shuttle"
    } as Alert;
    const outsideActivePeriodAlert: Alert = {
      active_period: beforeNow(),
      lifecycle: "new",
      effect: "shuttle"
    } as Alert;

    expect(isActiveDiversion(nonCurrentLifecyleAlert)).toBeFalsy();
    expect(isActiveDiversion(outsideActivePeriodAlert)).toBeFalsy();
  });

  test("false if not a diversion", () => {
    const nonDiversionAlert: Alert = {
      active_period: aroundNow(),
      lifecycle: "new",
      effect: "other"
    } as Alert;

    expect(isActiveDiversion(nonDiversionAlert)).toBeFalsy();
  });
});

describe("hasAnActiveDiversion", () => {
  const stopId: StopId = "place-sstat";
  const actvieDiversionAlert: Alert = {
    active_period: aroundNow(),
    lifecycle: "new",
    effect: "shuttle",
    informed_entity: { stop: [stopId] } as InformedEntitySet
  } as Alert;
  const nonActiveDiversionAlert: Alert = {
    active_period: aroundNow(),
    lifecycle: "new",
    effect: "other",
    informed_entity: { stop: [stopId] } as InformedEntitySet
  } as Alert;

  test("returns whether the list contains an active diversion alert", () => {
    expect(
      hasAnActiveDiversion(stopId, [
        actvieDiversionAlert,
        nonActiveDiversionAlert
      ])
    ).toBeTruthy();
    expect(hasAnActiveDiversion(stopId, [nonActiveDiversionAlert])).toBeFalsy();
  });
});

describe("alertsByRoute", () => {
  test("it should group alerts across multiple routes", () => {
    const alerts = [
      {
        id: "1234",
        informed_entity: {
          route: ["441442", "442"]
        }
      },
      {
        id: "4321",
        informed_entity: {
          route: ["442", "53"]
        }
      }
    ] as Alert[];
    const result = alertsByRoute(alerts);
    expect(Object.keys(result).length).toBe(3);
    expect(result["442"].length).toBe(2);
    expect(result["441442"].length).toBe(1);
    expect(result["53"].length).toBe(1);
  });
});

describe("alertsByDirectionId", () => {
  test("it should group alerts by directionId, filtering out both directions", () => {
    const alerts = [
      {
        id: "1234",
        informed_entity: {
          direction_id: [0]
        }
      },
      {
        id: "4321",
        informed_entity: {
          direction_id: [null]
        }
      },
      {
        id: "0987",
        informed_entity: {
          direction_id: [0, 1]
        }
      }
    ] as Alert[];
    const result = alertsByDirectionId(alerts);
    expect(Object.keys(result).length).toBe(2);
    expect(result[1].length).toBe(1);
    expect(result[0].length).toBe(2);
  });
});

describe("alertsAffectingBothDirections", () => {
  test("should return only the alerts that affect both directions", () => {
    const alerts = [
      {
        id: "1234",
        informed_entity: {
          direction_id: [0]
        }
      },
      {
        id: "3333",
        informed_entity: {
          direction_id: [null]
        }
      },
      {
        id: "0987",
        informed_entity: {
          direction_id: [1]
        }
      },
      {
        id: "4444",
        informed_entity: {
          direction_id: []
        }
      },
      {
        id: "5555",
        informed_entity: {
          direction_id: null
        }
      }
    ] as Alert[];
    const result = alertsAffectingBothDirections(alerts);
    expect(result.length).toBe(3);
    expect(result[0].id).toBe("3333");
    expect(result[1].id).toBe("4444");
    expect(result[2].id).toBe("5555");
  });
});
