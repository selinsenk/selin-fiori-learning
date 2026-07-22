# 01 — How it all fits together

## The three folders

```
db/    →  what data exists            (the model)
srv/   →  what the outside world sees (the service)  + the business logic
app/   →  the screens                  (which are generated, not written)
```

That is the whole architecture. It is also the architecture of a real S/4HANA
app, which is why `abap-reference/` has the same three layers under different
names.

## What happens when you open the app

Follow this once and Fiori Elements stops being magic.

```
 1. Browser loads  app/taxbalance/webapp/index.html
        │
        │  the <script> tag pulls SAPUI5 from https://ui5.sap.com/1.148.5/
        ▼
 2. ComponentSupport starts  Component.js
        │
        │  Component.js says only: "read manifest.json"
        ▼
 3. manifest.json says three important things:
        - my data source is  /odata/v4/tax-balance/
        - my pages are  sap.fe.templates.ListReport  and  ObjectPage
        - both are bound to  contextPath: "/CompanyLayers"
        │
        ▼
 4. Fiori Elements fetches  /odata/v4/tax-balance/$metadata
        │
        │  This is the decisive step. That document contains every annotation
        │  from srv/annotations.cds, translated into XML.
        ▼
 5. Fiori Elements READS the annotations and BUILDS the screen:
        UI.SelectionFields  → renders two filter fields
        UI.LineItem         → renders four table columns
        UI.Facets           → renders two tabs
        Capabilities        → decides which buttons to show
        │
        ▼
 6. The user presses Go → the framework issues
        GET /CompanyLayers?$filter=companyCode eq '1000' and layerID eq '01'
        │
        ▼
 7. CAP receives it, runs any handlers in srv/tax-service.js, queries SQLite,
    returns JSON.
```

**The app contains no code that mentions "Company Code" or "tab" or "table".**
Everything visible came from step 5, driven by annotations written in the
backend. That is what "metadata-driven UI" means, and it is why the same
frontend works unchanged against ABAP.

## Where each requirement is implemented

| What the brief asked for | Where it lives | Line of code |
|---|---|---|
| User must pick Company Code + Layer before entering | `srv/tax-service.cds` | `FilterRestrictions.RequiredProperties` |
| Those two fields appear as dropdowns | `srv/annotations.cds` | `UI.SelectionFields` + `Common.ValueList` |
| Clicking a row opens the detail screen | `app/.../manifest.json` | the `routing.routes` block |
| Detail screen has two tabs | `srv/annotations.cds` + manifest | `UI.Facets` (two collection facets) + `"sectionLayout": "Tabs"` |
| Tab 1 shows the country | `srv/annotations.cds` | `UI.FieldGroup #CountryInfo` |
| Tab 1 rows are addable and editable | `srv/tax-service.cds` | `@odata.draft.enabled` + the composition |
| New rows can be typed inline | `app/.../manifest.json` | `"creationMode": {"name": "InlineCreationRows"}` |
| Tab 2 shows GL accounts | `srv/annotations.cds` | `UI.LineItem` on `GLAccounts` |
| Calculated Amount column | `db/schema.cds` + `srv/tax-service.js` | `virtual calculatedAmount` + the `after('READ')` handler |
| No Create/Delete on the header | `srv/tax-service.cds` | `@Capabilities.InsertRestrictions` / `DeleteRestrictions` |

Notice how much of it is **backend annotation**, not frontend code. That
distribution is normal for Fiori Elements and it surprises people coming from
React or Angular.

## Why the calculation is done in the backend

`calculatedAmount = balanceAmount × (sum of tax rates) ÷ 100` could obviously be
done in JavaScript in the browser. It is done in `srv/tax-service.js` instead,
deliberately:

1. **Every consumer gets it.** An Excel export, a second app, or a machine-to-
   machine API caller all see the same number. UI-side maths is invisible to them.
2. **It is the only option in Fiori Elements.** There is no place to put
   arbitrary per-cell logic in a generated table without writing a custom column
   extension — the framework expects the field to exist in the service.
3. **It mirrors what ABAP must do.** In S/4HANA the value comes from a virtual
   element filled by an ABAP class. Keeping the architecture parallel is the
   whole point of this project.
4. **It keeps the rule in one place.** Tax logic changes; you want to change it
   in one file, not in every client.

## The draft mechanism, concretely

This is the part most worth internalising, because every transactional S/4HANA
app works this way.

```
        ACTIVE TABLE                      DRAFT TABLE
   (the real, saved data)          (each user's private copy)
   ┌────────────────────┐          ┌────────────────────┐
   │ 1000 / 01          │          │                    │
   │  VAT Standard 19.0 │          │      (empty)       │
   │  Soli          5.5 │          │                    │
   └────────────────────┘          └────────────────────┘
             │
             │  user presses EDIT   →   POST .../draftEdit
             ▼
   ┌────────────────────┐          ┌────────────────────┐
   │ 1000 / 01          │  copied  │ 1000 / 01          │
   │  VAT Standard 19.0 │ ───────► │  VAT Standard 19.0 │
   │  Soli          5.5 │          │  Soli          5.5 │
   └────────────────────┘          └────────────────────┘
                                             │
                          user types a new row (10%)
                                             ▼
   ┌────────────────────┐          ┌────────────────────┐
   │  unchanged         │          │  + Test Rate  10.0 │
   │  Tab 2 → 24.5%     │          │  Tab 2 → 34.5%     │
   └────────────────────┘          └────────────────────┘
             │
             │  user presses SAVE   →   POST .../draftActivate
             ▼
   ┌────────────────────┐          ┌────────────────────┐
   │ 1000 / 01          │          │                    │
   │  VAT Standard 19.0 │          │   (deleted again)  │
   │  Soli          5.5 │          │                    │
   │  Test Rate    10.0 │          │                    │
   └────────────────────┘          └────────────────────┘
```

Two consequences to remember:

- Every URL carries `IsActiveEntity=true|false`, because the same key exists in
  both tables.
- Backend code that reads related data **must decide which table to read**.
  `srv/tax-service.js` does this in `isDraftRequest()`, and it is the one piece
  of that file that took real debugging: CAP silently rewrites the query to
  point at `CompanyLayers.drafts` and *removes* `IsActiveEntity`, so checking
  the flag does not work — you must check the entity name. The comment in the
  file records this.

## Try it yourself

With the server running:

```bash
curl -u alice: "http://localhost:4004/odata/v4/tax-balance/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)/glAccounts?\$select=accountNumber,balanceAmount,calculatedAmount"
```

Then run the draft sequence in `docs/06-exercises.md` and watch the number change.
