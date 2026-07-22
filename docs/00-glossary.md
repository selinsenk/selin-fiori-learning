# 00 — Glossary

Every term this project uses, in plain words. Skim it now; come back whenever a
word in the code confuses you. Terms are grouped, not alphabetical, because
related ideas are easier to learn together.

---

## The big picture words

**SAP Fiori**
SAP's design system — the rules for how SAP apps should look and behave. Not a
technology. "A Fiori app" just means an app that follows those rules.

**SAPUI5**
The actual JavaScript framework that renders Fiori apps in the browser. This is
the code you load from `https://ui5.sap.com/...`. It contains hundreds of
controls (buttons, tables, charts).

**OpenUI5**
The open-source subset of SAPUI5. Important detail: it does **not** include the
`sap.fe.*` (Fiori Elements) libraries. So a Fiori Elements app must use SAPUI5.

**Freestyle SAPUI5**
An app where you write the screens yourself — XML views, controllers, the lot.
Full control, much more code.

**Fiori Elements**
The opposite approach, and what this project uses. You write **no** screen code.
You annotate your data model, and SAP's ready-made templates generate the screen
at runtime. Fewer options, far less code, and consistent with every other SAP app.

**Floorplan**
A standard page layout. The two we use:
- **List Report** — filter bar on top, table below. Our Screen 1.
- **Object Page** — header, then sections/tabs of details. Our Screen 2.
Others exist (Overview Page, Analytical List Page, Worklist).

---

## Data and service words

**OData**
The protocol between browser and server. It is REST plus a strict, machine-
readable description of the data. That description is what lets Fiori Elements
build screens automatically. Two versions matter: **V2** (older, SAP Gateway
era) and **V4** (current, what we use).

**Entity**
A "thing" in the model — roughly a table. `CompanyLayers` is an entity.

**Entity set**
The collection of all rows of an entity, and the thing you see in a URL:
`/CompanyLayers`.

**Entity type**
The shape (fields and types) of one row.

**Key**
The field(s) that identify one row. Ours are compound:
`CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)`.

**Navigation property**
A named link from one entity to another. `glAccounts` is a navigation property
of `CompanyLayers`, which is why this URL works:
`/CompanyLayers(...)/glAccounts`.

**`$metadata`**
The document describing the whole service — every entity, field, type,
relationship and annotation. Open
<http://localhost:4004/odata/v4/tax-balance/$metadata> and you are looking at
the contract that drives the entire UI.

**System query options** — the `$`-prefixed URL parameters:

| Option | Means | Example |
|---|---|---|
| `$select` | only these fields | `$select=accountNumber,balanceAmount` |
| `$filter` | only these rows | `$filter=companyCode eq '1000'` |
| `$expand` | include related data | `$expand=taxRates` |
| `$orderby` | sort | `$orderby=accountNumber desc` |
| `$top` / `$skip` | paging | `$top=20&$skip=40` |
| `$count` | how many rows | `$count=true` |

**CRUD**
Create / Read / Update / Delete — mapped to HTTP POST / GET / PATCH / DELETE.

---

## CDS words

**CDS (Core Data Services)**
SAP's language for describing data models. It exists in two dialects:
- **CAP CDS** — runs on Node.js. Our `db/schema.cds`, `srv/*.cds`.
- **ABAP CDS** — runs inside S/4HANA. Our `abap-reference/02-...`, `03-...`.
Same ideas, slightly different syntax.

**Entity vs. view**
In CAP an entity usually becomes a table. In ABAP CDS a view entity is always a
*view* over tables that already exist.

**Association**
A declared relationship — "a join you define once and reuse". Writing
`company.country.name` follows two associations.

**Composition**
A stronger association meaning **ownership** (parent–child). Deleting the parent
deletes the children. Our `CompanyLayers` → `TaxRates` is a composition; our
`CompanyLayers` → `GLAccounts` is only an association, because G/L accounts are
not owned by a company/layer selection.

**Managed vs. unmanaged association** *(CAP)*
Managed = you give only the target, CAP invents the foreign key columns
(`parent_companyCode`). Unmanaged = you write the `on` condition yourself.
ABAP CDS only has the unmanaged style.

**Projection**
A view that selects from another view, exposing a subset. Both stacks use the
word: `as projection on db.CompanyLayers` / `as projection on ZI_TB_CompanyLayer`.

**Interface view (`ZI_`) vs. consumption view (`ZC_`)** *(ABAP)*
`ZI_` = the stable, reusable truth. `ZC_` = shaped for one specific app, carries
the UI annotations, disposable. CAP does the same split as `db/` vs `srv/`.

**Virtual element**
A field with no database column, filled by code at read time. Our
`calculatedAmount`. Powerful, but **cannot be sorted or filtered by the
database** — a limitation in both stacks.

---

## Annotation words

**Annotation**
A labelled fact attached to a model element: `@title: 'Company Code'`,
`@UI.LineItem: [...]`. Some are documentation; most are instructions to a
framework.

**Vocabulary**
A published dictionary of annotation terms. `UI`, `Common`, `Capabilities`,
`Measures` are vocabularies. `UI.LineItem` = the term `LineItem` from the `UI`
vocabulary; its full name is `com.sap.vocabularies.UI.v1.LineItem`.

**Qualifier**
A name that lets you have several annotations of the same term on one entity:
`UI.FieldGroup #CountryInfo` and `UI.FieldGroup #HeaderInfo`. In ABAP:
`qualifier: 'CountryInfo'`.

**The terms this project uses**

| Term | Effect |
|---|---|
| `UI.SelectionFields` | which fields appear in the filter bar |
| `UI.LineItem` | the columns of a table |
| `UI.Facets` | the sections/tabs of an Object Page |
| `UI.FieldGroup` | a named group of fields, rendered where a facet points at it |
| `UI.HeaderInfo` | the object's name and title |
| `UI.HeaderFacets` | content in the page header, above the tabs |
| `UI.Hidden` | keep in the service, remove from the screen |
| `Common.Text` + `Common.TextArrangement` | show "Musterhaus GmbH (1000)" instead of "1000" |
| `Common.ValueList` | the F4 / value-help dropdown |
| `Capabilities.*Restrictions` | what the client may do — drives which buttons render |
| `Measures.ISOCurrency` | "this number is money, in that currency field" |

**Metadata extension (`.ddlx`)** *(ABAP)*
A separate file holding only the UI annotations for a CDS view. Its purpose is
layering (`#CORE` < `#CUSTOMER`), so a customer can restyle an SAP app without
modifying it. Our `srv/annotations.cds` plays the same role.

---

## Transactional / RAP words

**Draft**
SAP's editing model. Pressing **Edit** creates a private copy of the row; you
type into the copy; **Save** writes it over the real row; **Cancel** throws it
away. Your unsaved work survives a browser crash. Every URL in a draft-enabled
service carries `IsActiveEntity=true|false`.

**Active entity / draft entity**
`IsActiveEntity=true` = the real saved row. `false` = your private copy.
Physically they live in two different tables.

**RAP (ABAP RESTful Application Programming Model)**
The current way to build transactional apps in ABAP: CDS views + a behavior
definition + a service definition + a service binding.

**Behavior definition (`.bdef`)**
The file that says what may be done to a business object — `create`, `update`,
`delete`, `with draft`, validations, actions. The RAP counterpart of CAP's
`@odata.draft.enabled` and `@Capabilities`.

**Managed vs. unmanaged BO** *(RAP)*
Managed = the framework writes to the database for you. Unmanaged = you write
every database operation yourself (used to wrap legacy applications).

**Behavior pool / behavior implementation class (`ZBP_*`)**
The ABAP class holding the extras a behavior definition declared.

**Validation**
Code that runs before save and can refuse it, with a message.

**Determination**
Code that runs on change and *fills* fields automatically.

**Action**
A custom button. Declared in the behavior definition, implemented in the
behavior pool, rendered by Fiori Elements without any UI code.

**EML (Entity Manipulation Language)**
The ABAP statements for talking to a business object: `READ ENTITIES`,
`MODIFY ENTITIES`, `COMMIT ENTITIES`. Reads through the framework, so it sees
draft data.

**ETag**
Optimistic locking. The client gets a timestamp when it reads, sends it back
when it writes; a mismatch means someone else changed the row first, and the
write is rejected instead of silently overwriting.

**Service definition (`.srvd`) / Service binding (`.srvb`)** *(ABAP)*
Definition = *which* entities are published. Binding = *how* (OData V2 or V4, UI
or Web API) and at which URL. CAP fuses both into `service X @(path:'...')`.

---

## Tooling words

**CAP (SAP Cloud Application Programming Model)**
The Node.js/Java framework we use as the local backend. `@sap/cds` is its
runtime, `@sap/cds-dk` its command-line tools.

**`cds serve` / `cds watch`**
Start the CAP server. `watch` also restarts on file changes.

**`@ui5/cli` (`ui5 serve`)**
The UI5 development server — used when the frontend runs separately from the
backend. Configured by `ui5.yaml`.

**Mock server**
A fake backend serving canned data so the frontend can be built before the real
backend exists. `@sap-ux/ui5-middleware-fe-mockserver` is the SAP one. We use
CAP instead, because it gives real draft handling and real persistence.

**manifest.json**
The descriptor of a UI5 app: its ID, its data sources, its models, its routing.
For a Fiori Elements app this file plus the annotations *are* the app.

**ADT (ABAP Development Tools)**
The Eclipse plug-in where all modern ABAP is written. SE80/SE11 are the old
SAP GUI transactions it replaces.

**Transport request**
How ABAP changes travel from the development system to test and production.
Every object you create is recorded in one. There is no ABAP equivalent of
"just copy the files".

**Client (`MANDT`)**
A logically separate dataset inside one SAP system — client 100 might be
production data, 200 training. Nearly every SAP table has it as the first key
field, and ABAP filters by it automatically.

---

## SAP finance words used in the example

**Company Code (`BUKRS`)**
The central legal/accounting unit in SAP FI. Every posting belongs to exactly
one, and each belongs to one country. Table `T001`.

**G/L account (`SAKNR`)**
General Ledger account — a bucket money is booked into, e.g. `400000` "Raw
material consumption". Tables `SKA1`/`SKB1`.

**ACDOCA**
The Universal Journal — the single line-item table at the heart of S/4HANA.
Real balance figures come from here, usually via released CDS views.

**Ledger / accounting principle**
The real-world counterpart of our invented "Layer": the same facts valued under
different rule sets (IFRS vs. local GAAP).
