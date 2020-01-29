import {
  ServiceGroupNames,
  groupServicesByDateRating,
  serviceDays,
  hasMultipleWeekdaySchedules,
  isInCurrentRating,
  isCurrentValidService,
  isInFutureRating,
  optGroupComparator,
  hasNoRating
} from "../service";
import { Service, DayInteger } from "../../__v3api";
import { Dictionary } from "lodash";
import { shortDate } from "../date";

export const services: Service[] = [
  {
    valid_days: [1, 2, 3, 4, 5],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2019-07-02",
    removed_dates_notes: { "2019-07-04": "Independence Day" },
    removed_dates: ["2019-07-04"],
    name: "Weekday",
    id: "BUS319-O-Wdy-02",
    end_date: "2019-08-30",
    description: "Weekday schedule",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test Rating"
  },
  {
    valid_days: [5],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2019-07-05",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Weekday",
    id: "BUS319-D-Wdy-02",
    end_date: "2019-08-30",
    description: "Weekday schedule",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test Rating"
  },
  {
    valid_days: [6],
    typicality: "typical_service",
    type: "saturday",
    start_date: "2019-07-06",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Saturday",
    id: "BUS319-P-Sa-02",
    end_date: "2019-08-31",
    description: "Saturday schedule",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test Rating"
  },
  {
    valid_days: [7],
    typicality: "typical_service",
    type: "sunday",
    start_date: "2019-07-07",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Sunday",
    id: "BUS319-Q-Su-02",
    end_date: "2019-08-25",
    description: "Sunday schedule",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test Rating"
  },
  {
    valid_days: [],
    typicality: "holiday_service",
    type: "sunday",
    start_date: "2019-07-07",
    removed_dates_notes: {},
    removed_dates: [],
    name: "B",
    id: "Bastille-Day",
    end_date: "2019-08-25",
    description: "Bastille Day",
    added_dates_notes: {
      "2019-07-13": "Bastille Day Eve",
      "2019-07-14": "Bastille Day",
      "2019-07-15": ""
    },
    added_dates: ["2019-07-13", "2019-07-14", "2019-07-15"],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test Rating"
  },
  {
    valid_days: [1, 2, 3, 4, 5],
    typicality: "unplanned_disruption",
    type: "weekday",
    start_date: "2019-07-15",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Weekday",
    id: "BUS319-storm",
    end_date: "2019-07-15",
    description: "Storm (reduced service)",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-06-25",
    rating_end_date: "2019-10-25",
    rating_description: "Test Rating"
  },
  {
    valid_days: [1, 2, 3, 4, 5],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2020-07-15",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Weekday",
    id: "weekday2020",
    end_date: "2020-09-15",
    description: "Another service",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2020-06-25",
    rating_end_date: "2020-10-25",
    rating_description: "Test Future Rating"
  },
  {
    valid_days: [1, 2, 3, 4, 5],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2019-07-07",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Weekday",
    id: "weekday2019",
    end_date: "2020-09-15",
    description: "Ferry service",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2019-07-07",
    rating_end_date: null,
    rating_description: ""
  },
  {
    valid_days: [1, 2, 3, 4, 5],
    typicality: "typical_service",
    type: "weekday",
    start_date: "2020-07-07",
    removed_dates_notes: {},
    removed_dates: [],
    name: "Weekday",
    id: "weekday2019-2",
    end_date: "2021-09-15",
    description: "CR service",
    added_dates_notes: {},
    added_dates: [],
    rating_start_date: "2020-07-07",
    rating_end_date: null,
    rating_description: ""
  }
];

const testDate = new Date("2019-07-15"); // sunday

describe("groupServicesByDateRating", () => {
  let grouped: Dictionary<Service[]>;
  beforeAll(() => {
    grouped = groupServicesByDateRating(services, testDate);
  });

  it("generates optgroup labels", () => {
    // just match on first word, since some labels may have extra verbiage
    const labelTexts = Object.keys(grouped).map(key => key.split(" ")[0]);
    const expectedLabelTexts = Object.values(ServiceGroupNames).map(
      key => key.split(" ")[0]
    );
    labelTexts.forEach(label => {
      expect(expectedLabelTexts.includes(label)).toBe(true);
    });
  });

  it("lists only typical_service services in the relevant rating as 'current'", () => {
    const currentKey = Object.keys(grouped).find(
      key => key.split(" ")[0] === ServiceGroupNames.CURRENT.split(" ")[0]
    );
    const currentServices = grouped[currentKey!];
    currentServices.forEach(service => {
      expect(service.typicality).toEqual("typical_service");
      expect(isInCurrentRating(service, testDate)).toBe(true);
    });
  });

  it("lists only holiday_service services as 'holiday'", () => {
    grouped[ServiceGroupNames.HOLIDAY].forEach(service => {
      expect(service.typicality).toEqual("holiday_service");
    });
  });

  it("lists future services as 'future'", () => {
    const futureKey = Object.keys(grouped).find(
      key => key.split(" ")[0] === ServiceGroupNames.FUTURE.split(" ")[0]
    );
    const futureServices = grouped[futureKey!];
    futureServices.forEach(service => {
      expect(isInFutureRating(service, testDate)).toBe(true);
    });
  });

  it("lists other services as 'other'", () => {
    grouped[ServiceGroupNames.OTHER].forEach(service => {
      expect(
        isInCurrentRating(service, testDate) &&
          service.typicality === "typical_service"
      ).toBe(false);
      expect(isInFutureRating(service, testDate)).toBe(false);
      expect(service.typicality).not.toEqual("holiday_service");
    });
  });

  it("annotates current schedules optgroup with rating name and rating end date", () => {
    const currentKey = Object.keys(grouped).find(
      key => key.split(" ")[0] === ServiceGroupNames.CURRENT.split(" ")[0]
    );
    const currentService = grouped[currentKey!][0];
    const name = `${ServiceGroupNames.CURRENT} (${
      currentService.rating_description
    }, ends ${shortDate(new Date(currentService.rating_end_date!))})`;
    expect(currentKey).toEqual(name);
  });

  it("annotates future schedules optgroup with rating name and rating start date", () => {
    const futureKey = Object.keys(grouped).find(
      key => key.split(" ")[0] === ServiceGroupNames.FUTURE.split(" ")[0]
    );
    const futureService = grouped[futureKey!][0];
    const name = `${ServiceGroupNames.FUTURE} (${
      futureService.rating_description
    }, starts ${shortDate(new Date(futureService.rating_start_date!))})`;
    expect(futureKey).toEqual(name);
  });
});

it("optGroupComparator sorts properly", () => {
  const c = "Current Schedules, ends Mar 15";
  const h = "Holiday Schedules";
  const f = "Future Schedules, starts Dec 25";
  const o = "Other Schedules";
  const expected = [c, h, f, o];
  const unsorted1 = [o, h, f, c];
  const unsorted2 = [h, o, f, c];
  const unsorted3 = [f, c, h, o];

  [unsorted1, unsorted2, unsorted3].forEach(groups => {
    expect(groups.sort(optGroupComparator)).toEqual(expected);
  });
});

it("isCurrentValidService evaluates whether date falls within a service's valid service dates", () => {
  const dateInCurrentServiceOnInvalidDate = isCurrentValidService(
    services[0],
    new Date("2019-07-07")
  );
  expect(dateInCurrentServiceOnInvalidDate).toBe(false);

  const dateInCurrentServiceOnRemovedDate = isCurrentValidService(
    services[0],
    new Date("2019-07-04")
  );
  expect(dateInCurrentServiceOnRemovedDate).toBe(false);

  const dateNotInCurrentService = isCurrentValidService(services[0], testDate);
  expect(dateNotInCurrentService).toBe(false);

  const dateInCurrentService = isCurrentValidService(
    services[0],
    new Date("2019-07-12")
  );
  expect(dateInCurrentService).toBe(true);
});

it("isInCurrentRating evaluates whether date falls within a service's rating dates", () => {
  const dateInRating = isInCurrentRating(services[0], testDate);
  expect(dateInRating).toBe(true);
  const dateNotInRating = isInCurrentRating(
    services[0],
    new Date("2019-03-15")
  );
  expect(dateNotInRating).toBe(false);
  const serviceWithoutRating = services[8];
  expect(isInCurrentRating(serviceWithoutRating, testDate)).toBe(false);
});

it("isInFutureRating evaluates whether date falls within service future rating dates", () => {
  const futureService = services[6];
  const dateInFutureRating = isInFutureRating(futureService, testDate);
  expect(dateInFutureRating).toBe(true);
  const dateNotInFutureRating = isInFutureRating(services[0], testDate);
  expect(dateNotInFutureRating).toBe(false);
  const serviceWithoutRating = services[8];
  expect(isInFutureRating(serviceWithoutRating, new Date("2020-08-08"))).toBe(
    false
  );
});

it("hasNoRating evaluates whether service does not fall within a rating", () => {
  const serviceWithRating = services[0];
  const serviceWithoutRating = services[8];
  expect(hasNoRating(serviceWithoutRating)).toEqual(true);
  expect(hasNoRating(serviceWithRating)).toEqual(false);
});

it("hasMultipleWeekdaySchedules indicates presence of multiple weekday schedules", () => {
  expect(hasMultipleWeekdaySchedules(services)).toEqual(true);

  const simplerServices = [services[0], services[2], services[3]];
  expect(hasMultipleWeekdaySchedules(simplerServices)).toEqual(false);
});

it("serviceDays lists weekday days of service", () => {
  expect(serviceDays(services[0])).toEqual("Weekday");
  expect(serviceDays(services[1])).toEqual("Friday");
  expect(serviceDays(services[2])).toEqual("");
  expect(serviceDays(services[3])).toEqual("");
  expect(serviceDays(services[4])).toEqual("");

  const someDays = {
    ...services[0],
    valid_days: [1, 3, 4] as DayInteger[]
  };

  expect(serviceDays(someDays)).toEqual("Monday, Wednesday, Thursday");

  const someConsecutiveDays = {
    ...services[0],
    valid_days: [1, 2, 3, 4] as DayInteger[]
  };

  expect(serviceDays(someConsecutiveDays)).toEqual("Monday - Thursday");
});
