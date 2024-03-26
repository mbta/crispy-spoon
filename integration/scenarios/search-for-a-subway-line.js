const { expect } = require("@playwright/test");

exports.scenario = async ({ page, baseURL }) => {
  await page.goto(`${baseURL}/search`);

  // We should be able to use down arrow and enter to select the first result.
  // But, the down arrow does not do anything.
  // The tab button takes me to the left side nav rather than the search results :(.
  await page
    .locator("input#search-global__input")
    .pressSequentially("Blue Line");
  await page.waitForSelector("div#search-results-container");
  await page.locator("div.c-search-result__hit a").first().click();

  await expect(page.locator("h1.schedule__route-name")).toHaveText(
    "Blue Line",
  );
  await page.waitForSelector("li.m-schedule-diagram__stop");
  await page.waitForSelector("div.m-schedule-diagram__predictions");
  await expect
    .poll(async () => page.locator("div.m-schedule-diagram__prediction-time").count())
    .toBeGreaterThan(1);

  await page.locator("a.alerts-tab").click();
  await expect(
    page.getByRole("heading", { name: "Alerts", exact: true }),
  ).toBeVisible();
};
