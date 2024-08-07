const { test, expect } = require("@playwright/test");
const AxeBuilder = require('@axe-core/playwright').default;
const fs = require("fs");
const path = require("path");

async function writeHTMLReport(pagePath, axeResult) {
  const reportName = `axe-report-${pagePath.replaceAll("/", "-")}-${axeResult.timestamp}.html`;
  const filePath = path.join(__dirname, "a11y-report-template.html");
  const html = await fs.promises.readFile(filePath, { encoding: 'utf8' });
  const $ = require('cheerio').load(html);
  $('body').append(`<script id="response" type="text/plain">${JSON.stringify(axeResult)}</script>`);
  const rendered = $.html();
  const reportPath = path.join(__dirname, reportName);
  fs.writeFileSync(reportPath, rendered);
  return { reportName, reportPath };
}

const axeTest = test.extend({
  makeAxeBuilder: async ({ page }, use, testInfo) => {
    const makeAxeBuilder = () => new AxeBuilder({ page })
      .withTags(['wcag22aa']);

    await use(makeAxeBuilder);
  }
});

function runAxeTest(pagePath) {
  axeTest(`${pagePath} landing page`, async ({ page, makeAxeBuilder }, testInfo) => {
    // default localhost:4001, specify HOST environment variable to change baseURL
    await page.goto(`${pagePath}`);

    // Avoid repeatedly surfacing errors from the page template by only 
    // testing the main content area unless we're testing the homepage.
    const axe = await makeAxeBuilder();
    if (pagePath !== "/") axe.include('main');

    // Analyze the page!
    const axeResult = await axe.analyze();

    // Attach screenshots of target HTML elements noted in the test failures
    const screenshots = await Promise.all(axeResult.violations
      .flatMap(({ id, nodes }) => {
        return nodes.flatMap(async ({ target }, index) => {
          const shot = await page.locator(target[0]).screenshot();
          return { shot, shotName: `${id}-${index}` };
        })
      })
    );
    screenshots.forEach(async ({ shot, shotName }) => {
      await testInfo.attach(shotName, { body: shot, contentType: 'image/png' });
    });

    // Create custom HTML report from the axe output JSON and attach to test
    const { reportName, reportPath } = await writeHTMLReport(pagePath, axeResult)
    await testInfo.attach(reportName, { path: reportPath });
    fs.unlinkSync(reportPath);

    expect(axeResult.violations.length).toEqual(0);
  });
}

axeTest.describe('has no automatically detectable accessibility issues', () => {
  /**
   *  Top-level pages from the main navigation.
   */
  [
    "/",
    "/schedules/subway",
    "/schedules/bus",
    "/schedules/commuter-rail",
    "/schedules/ferry",
    "/accessibility/the-ride",
    "/trip-planner",
    "/alerts",
    "/parking",
    "/bikes",
    "/guides",
    "/holidays",
    "/accessibility",
    "/transit-near-me",
    "/stops",
    "/destinations",
    "/maps",
    "/fares",
    "/fares/subway-fares",
    "/fares/bus-fares",
    "/fares/commuter-rail-fares",
    "/fares/ferry-fares",
    "/fares/charliecard-store",
    "/fares/charliecard",
    "/fares/retail-sales-locations",
    "/customer-support",
    "/customer-support/lost-and-found",
    "/language-services",
    "/transit-police",
    "/transit-police/see-something-say-something",
    "/mbta-at-a-glance",
    "/leadership",
    "/history",
    "/financials",
    "/events",
    "/news",
    "/policies",
    "/safety",
    "/quality-compliance-oversight",
    "/careers",
    "/pass-program",
    "/business",
    "/innovation",
    "/engineering/design-standards-and-guidelines",
    "/sustainability",
    "/projects"
  ].forEach(runAxeTest);

  /**
   *  Other specific pages and sub-pages to test. In the future, can write tests
   *  for different application states and interactions.
   */
  [
    "/schedules/Red/line",
    "/schedules/Orange/alerts",
    "/schedules/111/line",
    "/schedules/CR-Worcester/timetable",
    "/schedules/Boat-F1",
    "/stops/place-north",
    "/stops/1"
  ].forEach(runAxeTest);
});
