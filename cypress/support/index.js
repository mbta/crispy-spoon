// ***********************************************************
// This example support/index.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

import "./../../apps/site/assets/node_modules/cypress-file-upload";
import "./../../apps/site/assets/node_modules/cypress-iframe";
import "./commands";

Cypress.Screenshot.defaults({
  capture: "fullPage",
  disableTimersAndAnimations: false
});

Cypress.on('uncaught:exception', (err, runnable) => {
  // we expect a Google Maps API library error with message 't is not a function' if the tests start up too quickly
  // we don't want to fail the test so we return false
  if (err.message.includes('t is not a function')) {
    return false
  }
  // we still want to ensure there are no other unexpected
  // errors, so we let them fail the test
});
