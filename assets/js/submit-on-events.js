export default function(events, $) {
  $ = $ || window.jQuery;
  events.forEach(event => {
    function onEvent(ev) {
      $(ev.target)
        .siblings("label")
        .find(".loading-indicator")
        .removeClass("hidden-xs-up");
      const form = $(ev.target).parents("form");
      const action = form.attr("action");
      const serialized = form.serialize();

      window.location.assign(mergeAction(action, serialized));
    }

    function hideLoading(ev) {
      $(`[data-submit-on-${event}] label .loading-indicator`).addClass(
        "hidden-xs-up"
      );
    }

    function hideSubmits() {
      $(
        '<style type="text/css">[data-submit-on-' +
          event +
          "] [type=submit] {display: none;}</style>"
      ).appendTo($("head"));
    }

    $(document).on(event, "[data-submit-on-" + event + "] select", onEvent);
    $(document).on(event, "[data-submit-on-" + event + "] input", onEvent);
    document.addEventListener("DOMContentLoaded", hideLoading, {
      passive: true
    });
    hideSubmits();
  });
}

export function mergeAction(action, params, pathname) {
  if (!pathname) {
    if (typeof window !== "undefined") {
      // not set in tests
      pathname = window.location.pathname;
    }
  }
  if (typeof action === "undefined" || action === "" || action === "#") {
    return pathname + "?" + params;
  }
  if (action.charAt(0) == "#") {
    return pathname + "?" + params + action;
  }
  const replacedHash = action.replace(/#/, "?" + params + "#");
  if (replacedHash === action) {
    return action + "?" + params;
  }
  return replacedHash;
}
