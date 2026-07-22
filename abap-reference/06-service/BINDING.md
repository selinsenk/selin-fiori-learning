# The Service Binding — the step that has no file

A **service binding** (`.srvb`) is the last object in the chain, and it is the
one you cannot show as source code: in ADT it is a form-based editor, and its
content is mostly generated. So this file describes it instead.

## What it does

The service *definition* said **which entities**. The binding says **how they
are published**:

| You choose | Options | For our app |
|---|---|---|
| Binding type | OData V2 / **OData V4** | OData V4 |
| Scenario | **UI** / Web API | UI |
| Service name | free | `ZUI_TB_TAXBALANCE_O4` |

- **UI** scenario → optimised for Fiori consumption; draft is allowed.
- **Web API** scenario → for machine-to-machine integration; no draft, and the
  UI annotations are stripped out.

Creating the binding and pressing **Publish** (or **Activate**) is what makes
the service actually reachable over HTTP. Until you do, the URL returns 404.

## The URL you get

```
/sap/opu/odata4/sap/zui_tb_taxbalance_o4/srvd/sap/zui_tb_taxbalance/0001/
```

Broken down:

| Part | Meaning |
|---|---|
| `/sap/opu/odata4/` | the OData V4 entry point of the SAP Gateway |
| `sap/zui_tb_taxbalance_o4` | the **service binding** name |
| `srvd/sap/zui_tb_taxbalance` | the **service definition** name |
| `0001` | the service version |

Compare with CAP, where the whole thing was one annotation:
`@(path: '/odata/v4/tax-balance')` → `http://localhost:4004/odata/v4/tax-balance/`.

## The buttons in the binding editor

Once activated, the ADT editor gives you two things that are genuinely useful:

- **Preview** — launches a live Fiori Elements preview of the service, generated
  from your annotations. No frontend project needed at all. This is the fastest
  possible feedback loop when you are iterating on metadata extensions, and it
  is the closest ABAP equivalent to `npm start` in this project.
- **Service URL / Metadata** — opens `$metadata` in a browser, the same document
  we inspected at `http://localhost:4004/odata/v4/tax-balance/$metadata`.

## Then: the Fiori app

In a real landscape the frontend is a separate project. It is generated the same
way as this repo's `app/taxbalance/`, except that instead of pointing at
`http://localhost:4004`, the generator connects to the SAP system, lists the
published service bindings, and you pick `ZUI_TB_TAXBALANCE_O4` from a dropdown.

The generated `manifest.json` differs in exactly one meaningful place:

```jsonc
"dataSources": {
  "mainService": {
    // local CAP:
    "uri": "/odata/v4/tax-balance/",
    // real S/4HANA:
    "uri": "/sap/opu/odata4/sap/zui_tb_taxbalance_o4/srvd/sap/zui_tb_taxbalance/0001/",
    "type": "OData",
    "settings": { "odataVersion": "4.0" }
  }
}
```

Everything else — `sap.fe.templates`, the routing block, `sectionLayout: "Tabs"`,
the `controlConfiguration` for inline creation rows — is **identical**. That is
the practical payoff of this whole project: the frontend you built here is the
frontend you would ship against ABAP.

Deployment differs too: instead of being served by `cds serve`, the built app is
uploaded into the ABAP repository as a BSP application (`/UI5/UI5_REPOSITORY_LOAD`
or, nowadays, `npm run deploy` with `@sap/ux-ui5-tooling`'s `deploy-to-abap`
task), then surfaced through a Fiori Launchpad tile.
