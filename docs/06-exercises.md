# 06 — Exercises

Reading code teaches less than breaking it. Each exercise is small, reversible,
and makes one concept concrete. Do them roughly in order.

Restart the server after backend changes (`Ctrl+C`, then `npm start`) — or run
`npm run watch` in a normal terminal, which restarts by itself.

---

## A. Annotations drive everything

**A1 — Move a column.**
In `srv/annotations.cds`, in the `GLAccounts` `UI.LineItem`, swap the order of
`accountName` and `balanceAmount`. Reload. *The array order is the column order.*

**A2 — Delete the gate.**
In `srv/tax-service.cds`, comment out the `FilterRestrictions` block. Reload.
The "Go" button is enabled immediately and the table loads without any filter.
*One annotation was the entire "user must select first" requirement.* Put it back.

**A3 — Turn the tabs into a scrolling page.**
In `app/taxbalance/webapp/manifest.json`, change `"sectionLayout": "Tabs"` to
`"Page"`. Reload. Same annotations, same data, completely different layout, zero
code changed. This is the single most convincing demo of metadata-driven UI.

**A4 — Add a Create button by accident.**
In `srv/tax-service.cds`, delete `InsertRestrictions: { Insertable: false }`.
Reload — a "Create" button appears on the List Report. *The UI renders buttons
from backend capability annotations, not from frontend config.* Put it back.

**A5 — Change the text arrangement.**
On `companyCode` in `srv/annotations.cds`, change `#TextFirst` to `#TextOnly`,
then `#TextLast`. Watch how "1000" renders each time.

---

## B. OData by hand

**B1 — Find your annotations in the metadata.**
Open <http://localhost:4004/odata/v4/tax-balance/$metadata> and find
`UI.SelectionFields`. Confirm it lists exactly the two fields you wrote.

**B2 — Break a request on purpose.**
```
/CompanyLayers?$filter=companyCode eq 1000
```
(no quotes around 1000). Read the error. Now add the quotes. *Type mismatches in
`$filter` are the most common OData mistake.*

**B3 — Watch Fiori Elements talk.**
Open the browser dev tools → Network → filter by `tax-balance`. Use the app.
Notice: it never asks for `*`; every request has a tailored `$select`. Now you
know why `srv/tax-service.js` needs its `before('READ')` hook.

**B4 — Prove the calculation is server-side.**
```
/CompanyLayers(companyCode='2000',layerID='01',IsActiveEntity=true)/glAccounts?$select=accountNumber,balanceAmount,calculatedAmount
```
Company 2000 layer 01 has rates 20.00 + 3.00 = 23 %. Check one row by hand.

---

## C. Draft

**C1 — Run the draft lifecycle from the command line.**
Use the three `curl` commands in `docs/02-odata.md` §7. Between adding the rate
and activating, read `glAccounts` twice — once with `IsActiveEntity=false`, once
with `true`. Two different numbers from the same "row".

**C2 — Break the draft detection.**
In `srv/tax-service.js`, in `isDraftRequest()`, change
```js
if (typeof segment?.id === 'string' && segment.id.endsWith('.drafts')) return true
```
to `return false`. Restart, repeat C1: the draft read now shows the *saved*
rates. This is the exact bug that was found and fixed while building this
project. Revert it.

**C3 — See CAP's rewrite yourself.**
Start the server with `DEBUG_DRAFT=1 npx cds serve` and repeat C1. The console
prints `req.subject.ref` — you will see `TaxBalanceService.CompanyLayers.drafts`
and *no* `IsActiveEntity`. Printing `req.subject.ref` is the most useful CAP
debugging trick there is.

**C4 — Leave a draft behind.**
Edit a company/layer in the UI, type a rate, and close the browser without
saving. Reopen. The row is marked as having an unsaved draft, and you are offered
to resume it. Nobody wrote that feature — it came from `@odata.draft.enabled`.

---

## D. Business logic

**D1 — Change the formula to gross.**
In `srv/tax-service.js`, change
```js
const raw = balance * effectiveRatePercent / 100
```
to
```js
const raw = balance * (1 + effectiveRatePercent / 100)
```
Now the column is "balance including tax" rather than "the tax". Decide which
one your brief actually wanted, then set it back.

**D2 — Add validation.**
Reject a rate above 100 %. In the `init()` of `srv/tax-service.js`:
```js
this.before(['CREATE', 'UPDATE'], TaxRates, req => {
  if (req.data.rateValue > 100) {
    req.error({ target: 'rateValue', message: 'Rate must not exceed 100%' })
  }
})
```
Try to save 150 in the UI. The message appears next to the field, and the save is
blocked — no frontend code. Then read
`abap-reference/07-classes/ZBP_I_TB_COMPANYLAYER.clas.abap`, which does the same
thing in RAP with `validation … on save`.

**D3 — Add a field end to end.**
Add `note : String(200)` to `TaxRates` in `db/schema.cds`, then a `UI.DataField`
for it in the `TaxRates` `UI.LineItem` in `srv/annotations.cds`. Restart. A third
editable column appears. *That is the full workflow for a new field: model,
annotate, done.*

---

## E. Bridging to ABAP

**E1 — Translate an annotation.**
Take the `UI.LineItem` you edited in A1 and write it in ABAP CDS syntax. Check
yourself against `abap-reference/04-metadata-extension/ZC_TB_GLAccount.ddlx.asddlxs`.

**E2 — Translate a handler.**
Read `srv/tax-service.js` and
`abap-reference/07-classes/ZCL_TB_GLACC_VE.clas.abap` side by side. Find, in
each, (a) the place that declares which extra fields are needed, (b) the cache
that avoids re-reading rates per row, (c) the actual multiplication.

**E3 — Predict the difference.**
Before reading it: in the ABAP version, why can't the class simply
`SELECT FROM ztb_taxrate` and be correct? Then read the comment block at the end
of that file.

**E4 — Trace one field through every layer.**
Follow `rateValue` from `db/schema.cds` → `srv/tax-service.cds` →
`srv/annotations.cds` → the screen. Then follow `RATE_VALUE` through
`ZTB_TAXRATE.tabl` → `ZI_TB_TaxRate.ddls` → `ZC_TB_TaxRate.ddls` →
`ZC_TB_TaxRate.ddlx` → `.bdef`. Count the files each time. That count is the real
difference between the two stacks.

---

## F. Stretch goals

- **Per-rate-type columns.** The alternative the brief mentioned. Try it and find
  out *why* it is hard: the number of columns depends on the data, which no
  annotation can express. You would need a custom fragment or fixed
  `rate1/rate2/rate3` fields in the service. Discovering this limitation
  first-hand is worth more than the feature.
- **A custom action.** Add a "Copy rates from another layer" button: a bound
  action in `srv/tax-service.cds` plus an `this.on('copyRates', …)` handler.
  Then write the RAP equivalent in the `.bdef`.
- **Make it sortable.** Try sorting Tab 2 by Calculated Amount. It will not work,
  for the reason documented in `ZC_TB_GLAccount.ddls`. Fix it by storing the
  value in a real column, and notice what you give up (it can go stale).
- **A second layer of company data.** Add company code 4000 in a fourth country
  and give it GL accounts, so you can compare three currencies.
