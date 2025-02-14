/* eslint-disable */
import { Hooks } from "mbta_metro";
import "../vendor/fixedsticky";
import "../vendor/accessible-date-picker";
import "bootstrap/dist/js/umd/collapse";
import "bootstrap/dist/js/umd/modal";
import "bootstrap/dist/js/umd/tooltip";
import "bootstrap/dist/js/umd/dropdown";
import googleAnalytics from "./google-analytics";
import submitOnEvents from "./submit-on-events";
import collapse from "./collapse";
import setupGlobalNavigation from "../ts/app/global-navigation";
import modal from "./modal";
import supportForm from "./support-form";
import fixedsticky from "./fixedsticky";
import geoLocation from "./geolocation";
import addressSearch from "./address-search";
import googleTranslate from "./google-translate";
import translateAnalytics from "./translate-analytics.js";
import scrollTo from "./scroll-to";
import stickyTooltip from "./sticky-tooltip";
import timetableScroll from "./timetable-scroll";
import timetableStyle from "./timetable-style";
import timetableStick from "./timetable-stick";
import datePicker from "./date-picker";
import toggleBtn from "./toggle-on-click";
import * as TimeControls from "./time-controls/time-controls";
import * as TripPlannerLocationControls from "./trip-planner-location-controls";
import search from "./search";
import photoGallery from "./photo-gallery";
import { init as embeddedSearchInit } from "./algolia-embedded-search";
import * as homepageSearch from "./algolia-homepage-search";
import * as globalSearch from "./algolia-global-search";
import fullstory from "./fullstory";
import inputFocus from "./input-focus";
import setupChannels from "../ts/app/channels";
import CRTrains from "./cr-timetable-trains";
import { onload as alertItemLoad } from "./alert-item";
import dismissFullscreenError from "../ts/app/dismiss-fullscreen-error";
import tripPlannerWidget from "./trip-planner-widget";
import eventPageSetup from "./event-page-setup";
import previousEventsButton from "./view-previous-events";
import pslPageSetup from "./psl-page-setup.js";
import tabbedNav from "./tabbed-nav.js";
import { accordionInit } from "../ts/ui/accordion";
import initializeSentry from "../ts/sentry";
import DotcomHooks from "../ts/phoenix-hooks/index.ts";

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { ...Hooks, ...DotcomHooks },
  dom: {
    onBeforeElUpdated(from, to) {
      /*
      By default the open/closed state of a <details> element will not
      be preserved across LiveView rerenders. This creates some surprising
      behavior in the mode selector on the trip planner, where each time you
      change your selected mode, the accordion closes.  
      This code forces the `<details>` tag (what the accordion uses under the
      hood) to remember its open/closed state to avoid that bug. 
      */
      if (from.tagName == "DETAILS") {
        const openState = from.getAttribute("open");
        if (openState == "") {
          to.setAttribute("open", "");
        } else {
          to.removeAttribute("open");
        }
      }
    }
  }
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

initializeSentry();

document.body.className = document.body.className.replace("no-js", "js");

window.addEventListener("DOMContentLoaded", () => {
  document.body.className = document.body.className.replace("no-js", "js");
});

// Doesn't work with ProvidePlugin due to window.zepto dep
window.autocomplete = autocomplete;

// Polyfills
window.nextTick = function nextTick(f) {
  window.setTimeout(f, 0);
};

if ("outerHTML" in SVGElement.prototype) {
  Object.defineProperty(SVGElement.prototype, "outerHTML", {
    get() {
      const container = document.createElement("div");
      container.appendChild(this.cloneNode(true));
      return container.innerHTML;
    },
    enumerable: false,
    configurable: true
  });
}

// breakpoints defined in assets/css/_variables.scss
const breakpoints = { xs: 0, sm: 544, md: 800, lg: 1088, xxl: 1344 };

submitOnEvents(["blur", "change"]);
googleAnalytics();
setupGlobalNavigation();
collapse();
alertItemLoad();
modal();
supportForm();
fixedsticky();
inputFocus();
geoLocation();
addressSearch();
googleTranslate();
translateAnalytics();
scrollTo();
tabbedNav();
timetableScroll();
timetableStyle();
timetableStick();
datePicker();
toggleBtn();
search(window.$, breakpoints);
photoGallery();
stickyTooltip();
globalSearch.init();
homepageSearch.init();
embeddedSearchInit();
TripPlannerLocationControls.init();
TimeControls.init();
fullstory();
setupChannels();
CRTrains();
dismissFullscreenError();
tripPlannerWidget();
eventPageSetup();
previousEventsButton();
pslPageSetup();
accordionInit();
