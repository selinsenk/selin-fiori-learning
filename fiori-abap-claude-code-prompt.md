# Project Brief for Claude Code: Fiori Elements + ABAP Learning App (Tax Rate × Balance Sheet Tool)

## 1. Goal & Context

I want to learn **SAP Fiori (frontend)** and **ABAP (backend)** by building a small, realistic app end-to-end, since these are the technologies used at my company. I do **not** have access to a real SAP system (no BTP trial, no on-premise dev system) — everything must run and be testable **locally**, on my machine, without any live SAP backend.

Because of that constraint, please use this **two-layer architecture**:

1. **A working local mock backend** (Node.js/JavaScript) that actually serves the app's data over an OData-style service, so the Fiori app is fully functional and testable on my laptop.
2. **A parallel, realistic ABAP reference implementation** — real ABAP syntax (CDS views, a Service Definition/Service Exposure, a Behavior Definition if relevant, and an ABAP class with the business logic) that is **not executed**, but mirrors the mock backend's data model and logic exactly. This is the part I actually want to study — treat it as the "what this would look like in a real S/4HANA system" reference, heavily commented, explaining ABAP concepts as you go (CDS annotations, associations, service bindings, class methods, etc.).

Please explain your architecture and tooling choices as you implement them — I'm learning, not just shipping.

## 2. Frontend requirements

- Use **SAP Fiori Elements** (not freestyle SAPUI5) — I specifically want to learn the standard, metadata-driven SAP approach (List Report / Object Page floorplans, annotations-driven UI).
- Use the standard SAP tooling for this: SAPUI5 CLI (`@ui5/cli`), the Yeoman-based **SAP Fiori generator** (`yo` + `@sap/generator-fiori`), and a local **OData mock server** middleware for UI5 tooling (e.g. `@sap-ux/ui5-middleware-fe-mockserver` or the standard UI5 `MockServer`), so the Fiori Elements app runs entirely against local mock data.
- If a strict List Report / Object Page floorplan can't express something exactly as I describe below, use Fiori Elements' supported extension mechanisms (custom sections, controller extensions, custom fragments/columns) rather than switching to freestyle UI5 — and tell me when/why you had to do that.

## 3. App flow

**Screen 1 — "Login" / selection screen**
- Before entering the app, the user must select:
  - **Company Code** (dropdown/value help)
  - **Layer ID** (dropdown/value help)
- Model this using a Fiori Elements List Report filter bar (or an equivalent standard FE parameter-selection pattern) acting as the entry gate — the user picks Company Code + Layer ID, then proceeds into the detail view for that selection.

**Screen 2 — Detail view with two tabs**

Implement as an Object Page with two sections displayed as tabs (`useIconTabBar` / tab-style sections), for the Company Code + Layer ID chosen on Screen 1:

- **Tab 1 — "Tax Rates"**
  - Show the country the selected Company Code belongs to.
  - Let the user add/edit an editable list of rate entries for that country, each row = **Rate Type** (free-text label, e.g. "VAT Standard", "VAT Reduced", "Solidarity Surcharge" — user types the label themselves, no fixed dropdown list) + **Rate Value** (free numeric input, percentage).
  - These entries should be stored (in the mock backend) keyed by Company Code + Layer ID, so they can be reused in Tab 2.

- **Tab 2 — "Balance Sheet Comparison"**
  - Show a table of the selected company's GL accounts (Account Number, Account Name, Balance Amount) for the selected Layer ID.
  - Add a calculated column: **Calculated Amount = Balance Amount × (sum of the tax rate values entered in Tab 1, as a %)**.
    - *Assumption I'm making — flag if you disagree*: if I entered several rate rows in Tab 1 (e.g. VAT Standard 19% + Solidarity Surcharge 5.5%), sum them into one effective rate and apply it to each account's balance. If you think per-rate-type columns (one calculated column per tax rate row) would be clearer for learning purposes, propose it, but keep a single combined column as the default.

## 4. Data model (for the mock backend and the CDS/ABAP reference layer)

Please design proper entities/associations, roughly:
- `CompanyCode` (code, name, countryCode)
- `Country` (code, name)
- `Layer` (ID, description)
- `TaxRate` (companyCode, layerID, rateType [free text], rateValue [decimal])
- `GLAccount` (accountNumber, accountName, companyCode, layerID, balanceAmount)

Seed some realistic mock data (2–3 company codes across different countries, a handful of GL accounts and balances per company/layer) so the app is demoable immediately.

## 5. Dependencies to set up

Please install/scaffold whatever is needed, including but not limited to:
- Node.js tooling: `@ui5/cli`, `yo`, `@sap/generator-fiori` (or the current SAP-recommended equivalent — check for the latest official package names, since these change)
- A local OData V4 (or V2, your call — explain the trade-off) mock server middleware for UI5 tooling
- Any TypeScript/JS tooling you consider standard for a Fiori Elements project today

Verify versions are current before installing (don't assume from training data — check npm for the latest SAP Fiori tooling package names/versions).

## 6. Deliverables

1. Working local Fiori Elements app (`npm start` or `ui5 serve` runs it against the mock server) implementing the flow above.
2. A `/abap-reference` folder with the CDS views, service definition/exposure, and ABAP class(es) implementing the same data model and the tax × balance calculation logic — well-commented, written as if for deployment to a real S/4HANA system.
3. A short `README.md` explaining: project structure, how to run it, and a side-by-side mapping of "what the mock server does" ↔ "what the equivalent ABAP artifact does" — this mapping is the main thing I want to learn from.

Please start by proposing the folder structure and confirming the exact SAP Fiori tooling packages/versions you'll use, before generating code.
