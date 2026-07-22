# 02 — OData, learned by clicking

The fastest way to understand OData is to fire requests at the running service.
Start the server (`npm start` in the project root) and work through this page
with a browser or `curl`.

Base URL for everything below:

```
http://localhost:4004/odata/v4/tax-balance/
```

> CAP's mock authentication expects a user. In the browser you will be prompted —
> type any name (`alice`) and leave the password blank. With `curl`, add `-u alice:`.

---

## 1. The service document — what exists?

<http://localhost:4004/odata/v4/tax-balance/>

Returns the list of entity sets. This is the "table of contents" of the API, and
it matches exactly what `srv/tax-service.cds` chose to `expose`.

## 2. `$metadata` — the contract

<http://localhost:4004/odata/v4/tax-balance/$metadata>

**This is the single most important URL in the project.** Everything Fiori
Elements knows, it learned here. Search inside it for:

| Search for | You will find |
|---|---|
| `EntityType Name="GLAccounts"` | the fields and their types, including `calculatedAmount` — indistinguishable from a real column |
| `UI.LineItem` | the table columns you wrote in `srv/annotations.cds`, now as XML |
| `UI.Facets` | the two tabs |
| `Common.DraftRoot` | proof the entity is draft-enabled |
| `Action Name="draftEdit"` | the Edit button's backend action |
| `FilterRestrictions` | the mandatory-filter gate |

Every one of those came from an annotation you can read in `srv/`. Nothing in
the frontend duplicates it.

## 3. Reading rows

```
/CompanyLayers
```

All six company/layer combinations. Note each row carries `IsActiveEntity`.

```
/CompanyLayers?$filter=companyCode eq '1000'
```

`$filter` uses words, not symbols: `eq ne gt ge lt le`, joined by `and or not`.
Strings go in single quotes.

```
/CompanyLayers?$select=companyCode,layerID&$orderby=layerID desc&$top=3
```

Combine freely with `&`.

## 4. Reading ONE row — the key predicate

```
/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)
```

Because our key is compound, all parts must be named. This exact string is what
the browser URL shows after `#/` when you open the Object Page — Fiori Elements
builds it from the row you clicked.

## 5. Navigation — following a relationship

```
/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)/taxRates
/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)/glAccounts
```

Appending a navigation property name walks the association. This is precisely
what each tab's table does when you open it.

Add the calculated column:

```
/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)/glAccounts?$select=accountNumber,balanceAmount,calculatedAmount
```

`calculatedAmount` has no database column — `srv/tax-service.js` filled it after
the SELECT ran.

## 6. `$expand` — related data in one request

```
/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)?$expand=taxRates,company($expand=country)
```

Note the nesting: expand `company`, and inside it expand `country`. That is how
the annotation path `company.country.name` in `srv/annotations.cds` gets its data.

Watch the browser's network tab while using the app and you will see Fiori
Elements building requests like this by itself, selecting exactly the fields the
visible columns need — which is why `srv/tax-service.js` has a `before('READ')`
hook to add back the fields the calculation needs.

## 7. Writing — and the draft dance

Reading is `GET`. Writing is where draft appears.

```bash
B="http://localhost:4004/odata/v4/tax-balance"

# 1. EDIT  → create the private draft copy
curl -u alice: -X POST \
  "$B/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)/TaxBalanceService.draftEdit" \
  -H "Content-Type: application/json" -d '{"PreserveChanges":true}'

# 2. Add a row TO THE DRAFT  (note IsActiveEntity=false)
curl -u alice: -X POST \
  "$B/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=false)/taxRates" \
  -H "Content-Type: application/json" \
  -d '{"rateType":"Test Rate","rateValue":10.00}'

# 3. SAVE → activate the draft
curl -u alice: -X POST \
  "$B/CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=false)/TaxBalanceService.draftActivate" \
  -H "Content-Type: application/json" -d '{}'
```

Between steps 2 and 3, compare the two reads — the draft shows 34.5 %, the
active still shows 24.5 %. That is the point of draft.

Other verbs: `PATCH` on a row updates the fields you send; `DELETE` removes it.
`PUT` (full replace) is rarely used in SAP services.

---

## OData V2 vs V4 — why this project uses V4

You will meet both at work. The differences that actually bite:

| | V2 | V4 |
|---|---|---|
| Era in SAP | Gateway / SEGW, 2011→ | RAP, 2019→ |
| Fiori Elements library | `sap.ui.comp` based, `sap.fe` V2 | `sap.fe.templates` (what we use) |
| JSON shape | wrapped in `{"d": {"results": [...]}}` | plain `{"value": [...]}` |
| Dates | `/Date(1470009600000)/` | ISO 8601 |
| Draft | bolted on | designed in |
| `$expand` depth | limited | nested, with its own `$select`/`$filter` |
| Batch | required for most writes | optional |

If your company's system exposes V2 services, the *frontend concepts* in this
project all still apply — annotations, floorplans, facets — but the manifest
declares `"odataVersion": "2.0"` and the templates come from a different library.
Learn V4 first; it is where SAP is heading, and V2 is easier to read afterwards
than the other way round.

## Useful things to remember

- `$metadata` is your source of truth. When the UI does something odd, look
  there before looking at the JavaScript.
- Fiori Elements almost never asks for `*`. If a field is missing in a handler,
  suspect `$select` first.
- A 400 from CAP usually names the offending property in its message body —
  read the response, not just the status code.
