// Detects if the page is translated and notifies analyticis
const getNewLanguage = () => {
  const html = document.getElementsByTagName("html")[0];
  return html.getAttribute("lang")?.valueOf();
};

// adapted from: https://analytical42.com/2022/detect-track-translations-ga4/
// This code does its best to detect if the user changes the language of the page.
// Right now it fully supports logging from users changing the page language from the website itself regardless of the browser used
// This struggles with detecting and reporting the new language when the user uses the browser to
// change the language.
// Chrome - Full support, we can detect when the user translates the page, and what language the page is translated to
// Safari - Full support, we can detect when the user translates the page, and what language the page is translated to
// Edge - Half support, we can detect whne the user translates the page, just not what language they changed it to
// Firefox - No support, we cannot detect when the user translates the page
export default () => {
  // Start by checking if the MutationObserver API is available
  if (typeof MutationObserver === "function") {
    // Tell the observer to monitor for changes to HTML attributes
    const config = { attributes: true };
    // Build the function to run when a change is observed
    const callback = mutationList => {
      // Loop through each observed change
      for (let i = 0; i < mutationList.length; i += 1) {
        // Only do something if the change was on an attribute
        if (mutationList[i].type === "attributes") {
          if (
            // Check for Edge's browser translation attributes
            // Edge adds 2 attributes (_msttexthash and _msthash), so we only check for one to avoid duplicate logging
            mutationList[i].attributeName === "_msttexthash" ||
            // Check for Chrome, Google, and Safari's browser translation lang attribute
            mutationList[i].attributeName === "lang"
          ) {
            // Send an event to the dataLayer
            const newLanguage = getNewLanguage();
            window.dataLayer = window.dataLayer || [];
            window.dataLayer.push({
              event: "translate"
            });
            // Only log if we can detect the new language and it isn't english (the default of the page which some browsers do not update)
            if (newLanguage && newLanguage !== "en") {
              window.dataLayer.push({
                language: newLanguage
              });
            }
          }
        }
      }
    };
    // Create the actual observer
    const observer = new MutationObserver(callback);
    // Attach the observer to the <title> tag
    observer.observe(document.getElementsByTagName("title")[0], config);
    // Attach the observer to the <html> tag
    observer.observe(document.getElementsByTagName("html")[0], config);
  }
};
