import { assert } from "chai";
import sinon from "sinon";
import jsdom from "mocha-jsdom";
import { setupEventsPage } from "../event-page-setup";
import testConfig from "../../ts/jest.config";

const { testURL } = testConfig;

const eventsHubHTML = `
    <div class="container m-events-hub">
      <h1>Events</h1>
      <div class="row">
        <nav class="m-event-list__nav col-sm-3 fixedsticky sticky-top"></nav>
        <div class="col-sm-offset-1 col-sm-8">
          <div class="event-listing">
            <nav class="m-event-list__nav--mobile-controls fixedsticky sticky-top">
              <select class="c-select m-event-list__select">
                <option>Jump to</option>
                <option value="/events?month=1&year=2021">January 2021</option>
                <option value="/events?month=2&year=2021">February 2021</option>
                <option value="/events?month=3&year=2021">March 2021</option>
              </select>
            </nav>
            ${[1, 2, 3]
              .map(
                m => `<section id="${m}-2021" class="m-event-list__month 
                ${m === 2 ? "m-event-list__month--active" : ""}">
                <h2 class="m-event-list__month-header fixedsticky sticky-top">${m} 2021</h2>
                <ul>
                  <li>Event 1</li>
                  <li>Event 2</li>
                </ul>
                </section>`
              )
              .join("")}
          </div>
        </div>
      </div>
    </div>
    `;

function triggerScrollEvent(clock) {
  document.dispatchEvent(new window.Event("scroll"));
  clock.tick(); // fast forward set timeout (gets past window.requestAnimationFrame)
}

describe("setupEventsPage", () => {
  let $;
  let scrollIntoViewSpy;
  let getComputedStyleSpy;
  let getBoundingClientRectSpy;
  let toggleAttributeSpy;
  jsdom({ url: testURL });

  before(() => {
    /**
     * Set up sinon stubs to watch DOM functions we want to assert.
     *
     * JSDOM lacks various DOM API features, so for those functions we have to
     * manually assign the stubs to window.HTMLElement.prototype
     */
    scrollIntoViewSpy = sinon.stub();
    window.HTMLElement.prototype.scrollIntoView = scrollIntoViewSpy;

    toggleAttributeSpy = sinon.stub();
    window.HTMLElement.prototype.toggleAttribute = toggleAttributeSpy;
    getBoundingClientRectSpy = sinon.stub(
      window.HTMLElement.prototype,
      "getBoundingClientRect"
    );
    getComputedStyleSpy = sinon.stub(window, "getComputedStyle");
  });

  beforeEach(() => {
    $ = jsdom.rerequire("jquery");
    $("body").append("<div id=test />");
    $("#test").html(eventsHubHTML);
  });

  afterEach(() => {
    $("#test").remove();
    // reset all the stubs
    scrollIntoViewSpy.resetHistory();
    getComputedStyleSpy.resetHistory();
    getBoundingClientRectSpy.resetHistory();
    toggleAttributeSpy.resetHistory();
  });

  describe("scroll event listeners", () => {
    /**
     * Because the logic in these event listeners are inside a
     * window.requestAnimationFrame() call, we need to let the test bypass that.
     */
    let clock;

    beforeEach(() => {
      clock = sinon.useFakeTimers();
      window.requestAnimationFrame = setTimeout;
      window.cancelAnimationFrame = clearTimeout;
    });

    afterEach(() => {
      clock.restore();
    });

    it("will toggle 'stuck' attribute based on calculations on scroll", () => {
      // mock the positions. making these equal triggers the attribute!
      const t = 22;
      getBoundingClientRectSpy.callsFake(() => ({ top: t }));
      getComputedStyleSpy.callsFake(el => ({ top: `${t}px` }));

      setupEventsPage();
      sinon.assert.notCalled(getComputedStyleSpy);
      sinon.assert.notCalled(getBoundingClientRectSpy);
      sinon.assert.notCalled(toggleAttributeSpy);

      triggerScrollEvent(clock);
      sinon.assert.called(getComputedStyleSpy);
      sinon.assert.called(getBoundingClientRectSpy);
      sinon.assert.called(toggleAttributeSpy);
      sinon.assert.calledWith(toggleAttributeSpy, "stuck", true);

      // try not equal values. getComputedStyle().top will keep returning "22px"
      // but now getBoundingClientRect().top will return 20!
      getBoundingClientRectSpy.callsFake(() => ({ top: 20 }));

      triggerScrollEvent(clock);
      sinon.assert.calledWith(toggleAttributeSpy, "stuck", false);
    });

    it("will toggle 'js-nav-*' class name based on scroll direction", () => {
      const eventsHubPage = document.querySelector(".m-events-hub");
      getBoundingClientRectSpy.callsFake(() => ({ height: 10 }));

      // mock window.Y for this test with initial scroll position
      global.window = Object.assign(global.window, {
        scrollY: 222
      });
      setupEventsPage();
      assert.isFalse(eventsHubPage.classList.contains("js-nav-up"));
      assert.isFalse(eventsHubPage.classList.contains("js-nav-down"));

      // mock scroll up
      global.window = Object.assign(global.window, {
        scrollY: 20
      });
      triggerScrollEvent(clock);
      assert.isTrue(eventsHubPage.classList.contains("js-nav-up"));
      assert.isFalse(eventsHubPage.classList.contains("js-nav-down"));

      // mock scroll down
      global.window = Object.assign(global.window, {
        scrollY: 442
      });
      triggerScrollEvent(clock);
      assert.isTrue(eventsHubPage.classList.contains("js-nav-down"));
      assert.isFalse(eventsHubPage.classList.contains("js-nav-up"));
    });
  });

  it("scrolls to .m-event-list__month--active", () => {
    sinon.assert.notCalled(scrollIntoViewSpy);

    const activeMonth = $("section.m-event-list__month--active");
    assert.isOk(activeMonth);
    assert.equal(activeMonth.length, 1);

    setupEventsPage();

    sinon.assert.calledOnce(scrollIntoViewSpy);
  });

  it("navigates when .m-event-list__select changes", () => {
    setupEventsPage();

    const windowLocationSpy = sinon.spy(window.location, "assign");
    sinon.assert.notCalled(windowLocationSpy);

    const dateSelect = document.querySelector("select.m-event-list__select");
    const optionValue = "/events?month=2&year=2021";
    $(dateSelect)
      .find(`option[value="${optionValue}"]`)
      .attr("selected", "selected");
    const event = new window.Event("change", { bubbles: true });
    dateSelect.dispatchEvent(event);

    sinon.assert.calledOnce(windowLocationSpy);
    sinon.assert.calledWithExactly(windowLocationSpy, optionValue);
  });
});
