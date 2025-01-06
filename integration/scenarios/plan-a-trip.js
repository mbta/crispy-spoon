const { expect } = require("@playwright/test");

exports.scenario = async ({ page, baseURL }) => {
  await page.goto(`${baseURL}/trip-planner`);

  await expect(
    page.getByRole("heading", { name: "Trip Planner" }),
  ).toBeVisible();

  await page.locator("fieldset#trip-planner-locations-from input[type='search']").pressSequentially("North Station");
  await page.waitForSelector(
    "ul.aa-List",
  );
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");

  // The A location pin.
  await page.waitForSelector("#mbta-metro-pin-0");

  await page.locator("fieldset#trip-planner-locations-to input[type='search']").pressSequentially("South Station");
  await page.waitForSelector(
    "ul.aa-List",
  );
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");

  // The B location pin.
  await page.waitForSelector("#mbta-metro-pin-1");

  await page.getByText("Get trip suggestions").click();

  await expect
    .poll(async () =>
      page.locator("section#trip-planner-results").count(),
    )
    .toBeGreaterThan(0);
};
