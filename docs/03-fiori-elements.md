# 03 — Fiori Elements: the frontend, explained

## The whole frontend, listed

```
app/taxbalance/webapp/
├── index.html          22 lines of real content — loads UI5, starts the component
├── Component.js         6 lines of real content — "read my manifest"
├── manifest.json       the actual app definition
└── i18n/i18n.properties two translatable strings
```

There is **no view file, no controller, no table definition, no fetch call**.
If that feels wrong, that reaction is the thing to unlearn: in Fiori Elements the
UI is a *consequence* of the service metadata, not a separate artifact.

## `manifest.json`, block by block

JSON does not allow comments, so the explanation lives here. Open the file
alongside this page.

### `sap.app.dataSources`

```jsonc
"mainService": {
  "uri": "/odata/v4/tax-balance/",
  "type": "OData",
  "settings": { "odataVersion": "4.0" }
}
```

The **relative** URI matters. Because there is no host name, the same app works
against CAP on localhost, against a mock server, and against S/4HANA — whatever
is serving the page (or proxying, see `ui5.yaml`) provides the backend. When you
generate an app against a real system, only this string changes.

### `sap.ui5.dependencies`

```jsonc
"libs": { "sap.m": {}, "sap.ui.core": {}, "sap.fe.templates": {} }
```

`sap.fe.templates` is the Fiori Elements library. Its presence is what makes this
a Fiori Elements app rather than a freestyle one. It ships only in SAPUI5, not
OpenUI5 — hence the `ui5.sap.com` bootstrap URL in `index.html`.

### `sap.ui5.models[""]`

```jsonc
"": {
  "dataSource": "mainService",
  "settings": {
    "operationMode": "Server",
    "autoExpandSelect": true,
    "earlyRequests": true
  }
}
```

The `""` name makes it the **default model**, so bindings can be written as
`/CompanyLayers` with no model prefix.

| Setting | Effect |
|---|---|
| `operationMode: "Server"` | filtering, sorting and paging happen in the backend, not in the browser. Essential — a real G/L has millions of rows. |
| `autoExpandSelect: true` | the model works out `$select`/`$expand` from what the UI actually displays. This is why `srv/tax-service.js` needs a `before('READ')` hook to add back fields it needs but the UI does not show. |
| `earlyRequests: true` | fetch `$metadata` immediately at startup instead of on first use. Faster first paint. |

### `sap.ui5.routing`

```jsonc
"routes": [
  { "pattern": ":?query:",                   "name": "CompanyLayersList",       "target": "CompanyLayersList" },
  { "pattern": "CompanyLayers({key}):?query:","name": "CompanyLayersObjectPage", "target": "CompanyLayersObjectPage" }
]
```

Two routes = two screens. The pattern is matched against the URL hash:

- empty hash → List Report
- `#/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)` → Object Page

`{key}` captures the whole key predicate. `:?query:` is an optional query part
that Fiori Elements uses to carry filter state, so a URL can be bookmarked and
shared with its filters intact.

### The targets — where the templates are named

```jsonc
"CompanyLayersList": {
  "type": "Component",
  "name": "sap.fe.templates.ListReport",
  "options": { "settings": { "contextPath": "/CompanyLayers", ... } }
}
```

`name` selects the floorplan. `contextPath` says which entity set it renders.
Those two lines are the entire "screen definition".

### The settings worth knowing

```jsonc
"sectionLayout": "Tabs"
```

**This is the line that makes Screen 2's sections render as tabs.** Change it to
`"Page"` and the very same annotations render as one long scrolling page. Nothing
else changes. It is the clearest possible demonstration of what metadata-driven
UI buys you. (In Fiori Elements V2 the equivalent flag was called
`useIconTabBar` — you will see that name in older tutorials.)

```jsonc
"controlConfiguration": {
  "taxRates/@com.sap.vocabularies.UI.v1.LineItem": {
    "tableSettings": {
      "type": "ResponsiveTable",
      "creationMode": { "name": "InlineCreationRows" },
      "selectionMode": "Multi"
    }
  }
}
```

`controlConfiguration` is the escape hatch for things annotations cannot express,
keyed by the annotation path being configured. Here:

- `creationMode: InlineCreationRows` gives Tab 1 an empty row at the bottom of
  the table that you can type straight into. The alternatives are
  `NewPage` (navigate to a sub-object page) and `Inline` (an Add button).
- `selectionMode: "Multi"` gives checkboxes so several rows can be deleted at once.

Note the annotation term is spelled in full here
(`@com.sap.vocabularies.UI.v1.LineItem`), not as the short `@UI.LineItem`.

`variantManagement: "Page"` on the List Report enables the "Standard ✱" view
dropdown, letting users save their own filter/column sets. Free, from one word.

`initialLoad: "Auto"` means "load data on start only if filters are already
filled". Combined with the mandatory-filter annotation in the backend, this is
what produces the *"Let's get some results — start by providing your search or
filter criteria"* screen the brief asked for.

---

## What if annotations are not enough?

The brief asked to prefer standard extension mechanisms over going freestyle.
The escalation ladder, cheapest first:

1. **An annotation** — covers most of it.
2. **`controlConfiguration` in the manifest** — table type, creation mode,
   selection mode, default sort.
3. **A custom column or custom section** — an XML fragment you write, slotted
   into the generated page. Declared in the manifest under
   `content.body.sections`.
4. **A controller extension** — hook into `onBeforeRendering`, `onEdit`,
   `onSave`, etc., of the generated controller.
5. **A custom page** — a freestyle page inside an otherwise Fiori Elements app.

**We needed none of these.** Everything in the brief was expressible with
annotations plus manifest settings. That is worth noticing: the strict floorplans
handled a two-tab detail screen with an editable child table and a computed
column without a single line of UI code.

The one place you *would* reach for level 3 is the alternative the brief
mentioned — one calculated column **per** tax rate type. Because the number of
columns would then depend on the data, no annotation can express it; you would
need a custom fragment building columns dynamically, or a backend that returns a
fixed set of "rate 1 / rate 2 / rate 3" fields. That is exactly why the combined
single column is the better default, and not only for simplicity.

---

## The two ways to run the frontend

**Simple (what this project does by default)** — CAP serves both:

```bash
npm start                      # in the project root
# → http://localhost:4004/taxbalance/webapp/index.html
```

**Realistic (separate frontend server)** — what a real project does, because
the backend is on another machine:

```bash
npm start                      # terminal 1, project root → CAP on :4004
cd app/taxbalance && npm start # terminal 2 → UI5 tooling on :8080
```

The second one uses `app/taxbalance/ui5.yaml`, whose `fiori-tools-proxy`
middleware forwards `/odata/*` to port 4004. Against a real system you would
change one URL in that file and nothing else.
