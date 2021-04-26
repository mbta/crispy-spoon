import A11yDialog from "a11y-dialog";

function toggleAttributePolyfill() {
  if (!Element.prototype.toggleAttribute) {
    Element.prototype.toggleAttribute = function(name, force) {
      if (force !== void 0) force = !!force;

      if (this.hasAttribute(name)) {
        if (force) return true;

        this.removeAttribute(name);
        return false;
      }
      if (force === false) return false;

      this.setAttribute(name, "");
      return true;
    };
  }
}

function stickyPolyfill() {
  import("stickyfilljs").then(stickyfilljs => {
    const elements = document.querySelectorAll(".sticky-month");
    stickyfilljs.add(elements);
  });
}

function addInternetExplorerPolyfills() {
  toggleAttributePolyfill();
  stickyPolyfill();
}

function setupEventPopups() {
  /**
   * Why not use Bootstrap's popover? It's not equipped to handle having lots of
   * interactive content, doesn't support a close button, and as implemented the
   * UX for assistive tech users probably isn't ideal. For more, see "Making
   * popovers work for keyboard and assistive technology users" in
   * https://getbootstrap.com/docs/4.6/components/popovers/
   *
   * This implementation uses ally-dialog (https://a11y-dialog.netlify.app) as a
   * base to create accessible dialog windows for various use cases.
   */
  const calendarView = document.querySelector(".m-events-hub");

  // find all the event popup HTML elements
  const eventPopups = calendarView.querySelectorAll(".m-event-overlay");
  for (let i = 0; i < eventPopups.length; i++) {
    const el = eventPopups[i];
    const dialog = new A11yDialog(el);

    // Hide popup when user clicks outside popup, or on a different event
    const hideDialogLogicListener = function(event) {
      const path = event.composedPath();
      const eventClicked = path.find(function(x) {
        return x.className === "m-event-calendar__event";
      });
      const eventIdClicked =
        eventClicked && eventClicked.dataset.a11yDialogShow;
      if (eventIdClicked) {
        if (dialog._id !== eventIdClicked) dialog.hide();
      } else if (
        !path.find(function(x) {
          return x.className === "m-event-overlay";
        })
      ) {
        dialog.hide();
      }
    };
    document.addEventListener("click", hideDialogLogicListener);
    document.addEventListener("turbolinks:before-render", () =>
      document.removeEventListener("click", hideDialogLogicListener)
    );
  }
}

export function setupEventsListing() {
  const eventsHubPage = document.querySelector(".m-events-hub");
  // add event listener to navigate to page on dropdown select
  const dateSelects = eventsHubPage.querySelectorAll(".m-event-list__select");

  for (let i = 0; i < dateSelects.length; i++) {
    const select = dateSelects[i];
    select.classList.add("js")
    select.addEventListener("change", ({ target }) => {
      window.location.assign(target.value);
    });
  }

  const eventsListing = document.querySelector(".m-events-hub");
  if (!eventsListing) return;
  const control = eventsListing.querySelector(
    ".m-event-list__nav--mobile-controls"
  );
  let prevScroll = window.scrollY || document.documentElement.scrollTop;
  let prevDirection = 0;
  let direction = 0; // 0 - initial, 1 - up, 2 - down

  // add event listeners on scroll (and wheel on mobile)
  ["scroll", "wheel"].forEach(ev => {
    document.addEventListener(
      ev,
      () => {
        window.requestAnimationFrame(() => {
          // 1. toggle a shadow on the month header depending on if it's sticky
          const monthHeaders = eventsListing.querySelectorAll(
            ".m-event-list__month-header"
          );
          for (let i = 0; i < monthHeaders.length; i++) {
            const el = monthHeaders[i];
            const stickyStyleTop = parseInt(
              window.getComputedStyle(el).top.replace("px", ""),
              10
            ); // px defined in CSS
            const isStuck = el.getBoundingClientRect().top === stickyStyleTop;
            el.toggleAttribute("stuck", isStuck);
          }

          // 2. show or hide the month/year dropdowns on mobile depending on
          // whether the user scrolls up or down
          const curScroll =
            window.scrollY || document.documentElement.scrollTop;
          direction =
            // eslint-disable-next-line no-nested-ternary
            curScroll > prevScroll ? 2 : curScroll < prevScroll ? 1 : 0;

          const controlHeight = control.getBoundingClientRect().height;
          if (direction !== prevDirection) {
            // toggle the controls
            if (direction === 2 && curScroll > controlHeight) {
              // hide the controls
              eventsListing.classList.add("js-nav-down");
              eventsListing.classList.remove("js-nav-up");
            } else if (direction === 1) {
              // show the controls
              eventsListing.classList.add("js-nav-up");
              eventsListing.classList.remove("js-nav-down");
            }
            prevDirection = direction;
          }

          prevScroll = curScroll;
        });
      },
      { capture: false, passive: true }
    );
  });

  // scroll to active heading if available
  const activeMonthElement = eventsListing.querySelector(
    ".m-event-list__month--active"
  );
  if (activeMonthElement) activeMonthElement.scrollIntoView();
}

export default function() {
  document.addEventListener(
    "turbolinks:load",
    () => {
      if (document.querySelector(".m-events-hub")) {
        const isIE = !!document.documentMode;
        if (isIE) {
          addInternetExplorerPolyfills();
        }

        setupEventsListing();
      }

      if (document.querySelector(".m-events-hub")) {
        setupEventPopups();
      }
    },
    { passive: true }
  );
}
