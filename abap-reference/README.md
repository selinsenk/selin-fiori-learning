# `/abap-reference` — the same app, written for a real S/4HANA system

**None of the code in this folder runs on your laptop.** It cannot: ABAP only
runs inside an SAP system. This folder exists so you can read, side by side,
what every piece of the working CAP backend would look like in ABAP.

Read the folders in numerical order. Each one is a layer, and each layer is a
real, separate object type that you would create in ADT (ABAP Development Tools,
the Eclipse plug-in) with its own name and its own transport request.

| # | Folder | ABAP object type | What it is | CAP counterpart |
|---|--------|------------------|------------|-----------------|
| 1 | `01-tables/` | Database Table (`.tabl`) | The actual rows on disk | the `CREATE TABLE` that `db/schema.cds` compiles to |
| 2 | `02-cds-interface/` | CDS View Entity (`.ddls`) | Reusable, stable data model over the tables | `db/schema.cds` entities |
| 3 | `03-cds-projection/` | CDS Projection View (`.ddls`) | The API-facing subset | `srv/tax-service.cds` |
| 4 | `04-metadata-extension/` | Metadata Extension (`.ddlx`) | The UI annotations, kept in their own file | `srv/annotations.cds` |
| 5 | `05-behavior/` | Behavior Definition (`.bdef`) | What may be created/updated/deleted, and draft | `@odata.draft.enabled` + `@Capabilities` |
| 6 | `06-service/` | Service Definition + Binding | Which entities are published, and as what protocol | `service TaxBalanceService {}` + its `@path` |
| 7 | `07-classes/` | ABAP Class (`.clas`) | The business logic | `srv/tax-service.js` |
| 8 | `08-classic-gateway/` | *(explainer only)* | How this was done before RAP existed | — |

## The one-paragraph version

In RAP you build a **business object**. It has a *root entity* (here:
`ZI_TB_CompanyLayer`) and *child entities* (here: `ZI_TB_TaxRate`). You describe
its **data** with CDS views, its **behaviour** with a behavior definition, its
**look** with metadata extensions, and you **publish** it with a service
definition plus a service binding. The framework then generates a complete,
draft-enabled OData V4 service — you never write a single line of HTTP code.

That is exactly what CAP did for us in `/srv`, with different keywords.

## Naming conventions used here

SAP reserves the `Z` and `Y` prefixes for customer objects, so everything
starts with `Z`. Beyond that, these prefixes are SAP's own convention and you
will see them in every S/4HANA project:

| Prefix | Meaning | Example here |
|--------|---------|--------------|
| `ZI_` | **I**nterface view — reusable, stable, not for direct UI consumption | `ZI_TB_CompanyLayer` |
| `ZC_` | **C**onsumption view — shaped for one specific app/UI | `ZC_TB_CompanyLayer` |
| `ZR_` | **R**oot view (used instead of `ZI_` in some SAP guides) | — |
| `ZBP_` | **B**ehavior **P**ool — the class implementing a behavior definition | `ZBP_I_TB_COMPANYLAYER` |
| `ZUI_` | Service definition for a **UI** service | `ZUI_TB_TAXBALANCE` |
| `ZCL_` | A normal ABAP **cl**ass | `ZCL_TB_TAX_CALCULATOR` |

`TB` in the middle is just this project's own tag ("Tax Balance"). Real projects
use something similar to group their objects.

## Why interface views AND projection views?

This trips everyone up at first. The rule:

- **`ZI_` interface view** = "the truth about this data". Stable. Many apps and
  many other CDS views may reuse it. You change it rarely, because changing it
  affects everyone.
- **`ZC_` projection view** = "what *this one app* needs". It may rename fields,
  drop fields, add UI annotations, and be thrown away when the app is retired.

CAP has the same split, just less ceremony: `db/schema.cds` is the interface
layer, `srv/tax-service.cds` is the projection layer. You saw it there as
`entity CompanyLayers as projection on db.CompanyLayers`.

## What is deliberately simplified

This is a learning reference, not production code. In a real project you would
also have: authorization objects and CDS access controls (DCLs), number range
objects, proper message classes, extensibility annotations, and a full test
double framework setup. Where those are skipped, the file says so in a comment.
