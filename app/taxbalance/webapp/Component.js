/**
 * Component.js  —  the entry point of the UI5 application.
 *
 * This is the ONLY JavaScript file in the whole frontend, and it does nothing
 * but say "I am a Fiori Elements app, read my manifest.json".
 *
 * That is not a simplification for the tutorial - a real Fiori Elements app
 * genuinely looks like this. All the screens come from the annotations in
 * ../../srv/annotations.cds, interpreted by sap.fe.templates at runtime.
 *
 * sap.ui.define(...) is UI5's module system (AMD style):
 *   - the array lists the modules this file needs
 *   - the function receives them in the same order
 * It is UI5's equivalent of `require`/`import`.
 */
sap.ui.define(
  ["sap/fe/core/AppComponent"],
  function (AppComponent) {
    "use strict";

    // AppComponent is the Fiori Elements base class. Extending a plain
    // sap/ui/core/UIComponent instead would give a freestyle SAPUI5 app -
    // this single line is what makes the app "Fiori Elements".
    return AppComponent.extend("sap.learning.taxbalance.Component", {
      metadata: {
        // "json" means: load manifest.json and use it as the component's
        // descriptor - routing, models, dependencies and all.
        manifest: "json"
      }
    });
  }
);
