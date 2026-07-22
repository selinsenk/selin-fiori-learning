# 05 — The side-by-side mapping

The main thing this project exists to teach: **what the local backend does ↔ what
the equivalent ABAP artifact does.**

---

## Files

| Concern | Local (runs) | ABAP (reference) |
|---|---|---|
| Physical storage | `db/schema.cds` → SQLite tables | `abap-reference/01-tables/*.tabl` (DDIC tables) |
| Reusable data model | `db/schema.cds` entities | `abap-reference/02-cds-interface/ZI_TB_*.ddls` |
| App-facing shape | `srv/tax-service.cds` | `abap-reference/03-cds-projection/ZC_TB_*.ddls` |
| UI annotations | `srv/annotations.cds` | `abap-reference/04-metadata-extension/*.ddlx` |
| What may be changed | `@odata.draft.enabled`, `@Capabilities` | `abap-reference/05-behavior/*.bdef` |
| Publication / URL | `service X @(path:'…')` | `abap-reference/06-service/*.srvd` + service binding |
| Business logic | `srv/tax-service.js` | `abap-reference/07-classes/ZCL_*`, `ZBP_*` |
| Seed data | `db/data/*.csv` | table maintenance (SM30) or a setup report |
| Frontend | `app/taxbalance/` | **identical** — only `manifest.json`'s `uri` changes |

---

## Concepts

| Idea | CAP CDS | ABAP CDS / RAP |
|---|---|---|
| A table/entity | `entity X { }` | `define table ztb_x` + `define view entity ZI_X` |
| Primary key | `key id : String(4)` | `key id : bukrs not null` (+ mandatory `client` field) |
| Named type with label & value help | `@title` on the element | a **data element**, reused everywhere |
| Reference to another entity | `Association to one Y on …` | `association [0..1] to Y as _Y on …` |
| Ownership / parent-child | `Composition of many Y on Y.parent = $self` | `composition [0..*] of ZI_Y as _Y` + `association to parent` in the child |
| Foreign key created for you | managed association (`Association to one Y`, no `on`) | does not exist — always explicit |
| Subset for one app | `as projection on db.X` | `as projection on ZI_X` |
| Rewire an association to the projection | not needed | `_Y : redirected to ZC_Y` |
| Field with no column | `virtual calculatedAmount` | `virtual CalculatedAmount` + `@ObjectModel.virtualElementCalculatedBy` |
| Money + its currency | `@Measures.ISOCurrency: currency` | `@Semantics.amount.currencyCode: 'Currency'` |
| Read-only | `@readonly` | omit `update;` in the `.bdef`, or `field ( readonly )` |
| Draft editing | `@odata.draft.enabled` | `with draft;` + a draft table per entity |
| Mandatory filter | `@Capabilities.FilterRestrictions.RequiredProperties` | `@Consumption.filter.mandatory: true` |
| Value help | `@Common.ValueList` | `@Consumption.valueHelpDefinition` |
| Text for a key | `@Common.Text` + `TextArrangement` | `@ObjectModel.text.element` |
| Before-read hook | `this.before('READ', E, …)` | `GET_CALCULATION_INFO` |
| After-read hook | `this.after('READ', E, …)` | `CALCULATE` |
| Input validation | `this.before(['CREATE','UPDATE'], …)` + `req.error()` | `validation … on save` + `reported`/`failed` |
| Auto-fill a field | a `before` handler | `determination … on modify` |
| Custom button | a bound action in CDS + `this.on(…)` | `action` in `.bdef` + method in `ZBP_*` |
| Query the model in code | `SELECT.from(Entity)` | `SELECT … FROM ztb_x INTO TABLE @DATA(lt)` |
| Query respecting drafts | `SELECT.from(Entity.drafts)` | `READ ENTITIES … %is_draft = if_abap_behv=>mk-on` |
| Optimistic locking | draft locks / `@odata.etag` | `etag master` + `lock master` |
| Unit test | `cds.test` + jest | ABAP Unit (`FOR TESTING`), built in |
| Run it | `npm start` | activate objects, publish the service binding |

---

## The same feature, three times

**"Show a calculated column = balance × summed tax rate."**

**CAP model** (`db/schema.cds`):
```cds
virtual calculatedAmount : Decimal(15, 2)
```

**CAP logic** (`srv/tax-service.js`):
```js
this.after('READ', GLAccounts, async (rows, req) => {
  await enrich(toArray(rows), isDraftRequest(req))
})
```

**ABAP model** (`ZC_TB_GLAccount.ddls`):
```abap
@ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_TB_GLACC_VE'
virtual CalculatedAmount : ztb_amount,
```

**ABAP logic** (`ZCL_TB_GLACC_VE.clas.abap`):
```abap
METHOD if_sadl_exit_calc_element_read~calculate.
  LOOP AT ct_calculated_data ASSIGNING FIELD-SYMBOL(<ls_row>).
    ...
    <ls_typed>-calculatedamount = zcl_tb_tax_calculator=>calculate_amount( … ).
  ENDLOOP.
ENDMETHOD.
```

**And the frontend, for both** (`srv/annotations.cds` / `ZC_TB_GLAccount.ddlx`):
one more entry in the `LineItem`. The UI does not know or care that the field is
computed.

---

## Where the two genuinely differ

Not everything maps cleanly. The honest gaps:

**1. The client field.** Every ABAP table starts with `client` (`MANDT`), and
ABAP SQL filters by it automatically. CAP has no equivalent — its multitenancy
uses separate schemas. Do not look for `MANDT` in `db/schema.cds`; it is not
missing, it is a different model.

**2. Data elements and domains.** ABAP's three-layer type system (domain → data
element → field) gives you labels, F1 documentation and value help centrally,
inherited by every consumer. CAP has only `@title` on each element, repeated.
This is a real advantage of ABAP that is easy to underestimate.

**3. Two behavior files.** RAP separates the base behavior (what the object CAN
do) from the projection behavior (what THIS service exposes). CAP would express
that as a second `service` block. RAP's version scales better to "one business
object, five apps".

**4. Transport and lifecycle.** ABAP objects live in a repository, are recorded
in transport requests, and are activated rather than deployed. There is no
`git push` equivalent in the classic flow (abapGit exists and is widely used, but
it sits alongside the transport system, not instead of it).

**5. Draft plumbing.** CAP creates the shadow tables invisibly. RAP makes you
create a draft table per entity — visible, transportable, and something you can
inspect in the database. When our CAP draft detection broke, the fix required
discovering that CAP had *silently* rewritten the query to `CompanyLayers.drafts`.
In RAP you would have written `%is_draft` yourself and never been surprised.

**6. Where authorization lives.** CAP uses `@requires`/`@restrict` and a
`srv/**.cds` annotation. ABAP uses CDS access controls (`.dcl`) plus classic
authorization objects checked in the behavior pool. Both were skipped here; in a
finance app neither is optional.
