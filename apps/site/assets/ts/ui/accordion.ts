/**
 * Accordion element, with accessible keyboard interaction as
 * recommended by w3.org/WAI/ARIA/apg/patterns/accordion
 */

// toggles .is-expanded class on the accordion header <h3> wrapper to
// align with button.c-accordion-ui__trigger[aria-expanded] value
const addAccordionToggleObserver = (btn: Element): void =>
  new MutationObserver(mutations => {
    mutations.forEach(({ oldValue, target }): void => {
      const newValue = (target as HTMLElement).getAttribute("aria-expanded");
      if (newValue === oldValue) return;
      target.parentElement?.classList.toggle(
        "is-expanded",
        newValue === "true" && oldValue !== "true"
      );
    });
  }).observe(btn, {
    attributes: true,
    attributeOldValue: true,
    attributeFilter: ["aria-expanded"]
  });

export default function setupAccordion(rootElement: HTMLElement): void {
  rootElement
    .querySelectorAll(".c-accordion-ui--no-bootstrap")
    .forEach(accordion => {
      const accordionHeaders = accordion.querySelectorAll<HTMLButtonElement>(
        "button.c-accordion-ui__trigger"
      );

      function toggleItem(this: HTMLButtonElement): void {
        const isOpen = this.getAttribute("aria-expanded") === "true";
        accordionHeaders.forEach(btn => {
          btn.setAttribute(
            "aria-expanded",
            btn === this ? (!isOpen).toString() : "false"
          );
        });
      }

      accordionHeaders.forEach((btn, btnIndex, btnList) => {
        function toggleItemWithKeyboard(
          this: HTMLButtonElement,
          event: KeyboardEvent
        ): void {
          switch (event.code) {
            case "Space":
              toggleItem.call(this); // same as click or Enter
              break;
            case "ArrowDown":
              if (btnIndex < btnList.length - 1) {
                btnList[btnIndex + 1].focus(); // move to next accordion header
              }
              break;
            case "ArrowUp":
              if (btnIndex > 0) {
                btnList[btnIndex - 1].focus(); // move to prior accordion header
              }
              break;
            default:
              return;
          }
          // Cancel the default action to avoid it being handled twice
          event.preventDefault();
        }

        btn.addEventListener("click", toggleItem, false);
        btn.addEventListener("keyup", toggleItemWithKeyboard, false);
        addAccordionToggleObserver(btn); // respond to aria-expanded change
      });
    });
}
