# Tax Rates × Balance Sheet — a Fiori Elements + ABAP learning project

A small, complete SAP app built twice:

1. **A working version you can run on your laptop** — a real OData V4 service
   (CAP / Node.js) plus a Fiori Elements V4 frontend. Draft editing, value helps
   and a server-side calculated column all genuinely work.
2. **A parallel ABAP/RAP implementation** in [`abap-reference/`](abap-reference/)
   that is *not executed* — it is the study material, written as if for
   deployment to a real S/4HANA system and heavily commented.

The point is the pairing: every file in the running app has a labelled
counterpart in the ABAP folder.

---

## Quick start

```bash
npm install
npm start
```

Then open **<http://localhost:4004/taxbalance/webapp/index.html>**

You will be asked to log in — this is CAP's mock authentication. Type any user
name (e.g. `alice`) and leave the password empty.

In the app: pick **Company Code 1000** and **Layer 01**, press **Go**, click the
row.

> **Note on `npm run watch`:** `cds watch` adds auto-restart on file change and
> is the nicer dev loop, but its live-reload hangs when the process is not
> attached to a real terminal. Use it from your own terminal window; use
> `npm start` from tooling.

### Optional: run the frontend on its own server

What a real project does, since the backend normally lives elsewhere:

```bash
npm start                        # terminal 1 → CAP on :4004
cd app/taxbalance && npm start   # terminal 2 → UI5 tooling on :8080
```

`app/taxbalance/ui5.yaml` proxies `/odata/*` to port 4004. Against a real
S/4HANA system you change that one URL and nothing else.

---

## What the app does

**Screen 1 — selection gate (Fiori Elements *List Report*)**
A filter bar with Company Code and Layer ID, both with value-help dropdowns.
Both are **mandatory**: the Go button stays disabled until they are filled.
Clicking a result row opens Screen 2.

**Screen 2 — detail (Fiori Elements *Object Page*, sections rendered as tabs)**

- **Tab 1 — Tax Rates.** Shows the country the selected company code belongs to,
  and an editable table of rate entries (free-text *Rate Type* + numeric
  *Rate Value %*). New rows are typed inline. Editing is draft-based: Edit →
  type → Save, or Cancel to discard.
- **Tab 2 — Balance Sheet Comparison.** The company's G/L accounts for the
  chosen layer, with a **Calculated Amount** column =
  `Balance Amount × (sum of the Tab 1 rates) ÷ 100`, computed in the backend.

---

## Project layout

```
selin-fiori-learning/
├── db/                       the data model
│   ├── schema.cds            entities, associations, compositions
│   └── data/*.csv            seed data (3 companies, 3 countries, 30 G/L rows)
├── srv/                      the service
│   ├── tax-service.cds       what is exposed; draft; capabilities
│   ├── annotations.cds       ★ the entire UI, as annotations
│   └── tax-service.js        the calculated column + draft-aware reads
├── app/taxbalance/           the Fiori Elements app (4 real files)
│   ├── webapp/manifest.json  ★ floorplans, routing, table settings
│   ├── webapp/Component.js   6 lines
│   ├── webapp/index.html     the UI5 bootstrap
│   └── ui5.yaml              optional standalone dev server
├── abap-reference/           ★ the study material — does not run
│   ├── 01-tables/            DDIC tables + the data-element explainer
│   ├── 02-cds-interface/     ZI_* views
│   ├── 03-cds-projection/    ZC_* views (incl. the virtual element)
│   ├── 04-metadata-extension/*.ddlx — the UI in ABAP CDS
│   ├── 05-behavior/          .bdef — draft, what may be created/updated
│   ├── 06-service/           service definition + binding explainer
│   ├── 07-classes/           the logic + ABAP Unit tests
│   └── 08-classic-gateway/   how this looked before RAP (SEGW/DPC_EXT)
└── docs/                     the learning path — start here
```

---

## Suggested reading order

If you are new to all of this, read in this order. Each doc is self-contained
and assumes only the ones before it.

| | Document | Why |
|---|---|---|
| 1 | [`docs/00-glossary.md`](docs/00-glossary.md) | every term, in plain words. Skim now, return often. |
| 2 | [`docs/01-how-it-fits-together.md`](docs/01-how-it-fits-together.md) | the request lifecycle and where each requirement is implemented |
| 3 | [`docs/02-odata.md`](docs/02-odata.md) | OData learned by firing real requests at the running service |
| 4 | [`docs/03-fiori-elements.md`](docs/03-fiori-elements.md) | `manifest.json` block by block; when to use extensions |
| 5 | `srv/annotations.cds` | **read the actual file** — it is written as a tutorial |
| 6 | [`docs/04-abap-side.md`](docs/04-abap-side.md) | ABAP syntax survival kit + the guided tour of `abap-reference/` |
| 7 | [`docs/05-side-by-side-mapping.md`](docs/05-side-by-side-mapping.md) | the mapping tables |
| 8 | [`docs/06-exercises.md`](docs/06-exercises.md) | break things on purpose. This is where it sticks. |

---

## The mapping, in brief

The full version with concept-level tables is in
[`docs/05-side-by-side-mapping.md`](docs/05-side-by-side-mapping.md).

| What it does | Here (runs) | ABAP (reference) |
|---|---|---|
| Physical tables | `db/schema.cds` → SQLite | `01-tables/*.tabl` (DDIC) |
| Reusable data model | `db/schema.cds` | `02-cds-interface/ZI_TB_*.ddls` |
| App-facing shape | `srv/tax-service.cds` | `03-cds-projection/ZC_TB_*.ddls` |
| The UI, as metadata | `srv/annotations.cds` | `04-metadata-extension/*.ddlx` |
| Draft + what's editable | `@odata.draft.enabled`, `@Capabilities` | `05-behavior/*.bdef` (`with draft;`) |
| The published URL | `service … @(path:'…')` | `06-service/*.srvd` + service binding |
| Business logic | `srv/tax-service.js` | `07-classes/ZCL_*`, `ZBP_*` |
| Frontend | `app/taxbalance/` | **the same app**, only `manifest.json`'s `uri` differs |

---

## Tooling

Versions checked against npm at the time of writing.

| Package | Version | Role |
|---|---|---|
| Node.js | 24.16.0 | runtime (CAP 10 needs ≥ 22) |
| `@sap/cds` / `@sap/cds-dk` | 10.0.4 / 10.0.5 | the CAP backend |
| `@cap-js/sqlite` | 3.0.2 | in-memory database, reseeded from CSV on every start |
| SAPUI5 runtime | 1.148.5 (LTS) | loaded from `https://ui5.sap.com` |
| `@ui5/cli` | 4.0.58 | optional standalone frontend server |
| `@sap/ux-ui5-tooling` | 1.29.0 | the `fiori-tools-proxy` middleware |

### Choices made, and why

**OData V4, not V2.** V2 is the SEGW/Gateway generation; V4 is what modern RAP
services expose and what `sap.fe.templates` targets. Since the whole project is
about the ABAP mapping, V4 keeps both sides honest.

**CAP instead of a mock server.** The brief suggested
`@sap-ux/ui5-middleware-fe-mockserver`. CAP was chosen because it is a *real*
OData V4 server: draft editing, create/delete and persistence genuinely work, so
Tab 1 is a true demonstration rather than a simulation. It also has a second
payoff — CAP's `.cds` files are the close cousin of ABAP CDS, so the mapping in
`abap-reference/` is line-by-line rather than approximate.

**Annotations in the backend, not the frontend.** They could have gone in a
local `annotations.xml` in the app. Putting them in `srv/annotations.cds` is what
a real S/4HANA project does (they live in ABAP metadata extensions), and it makes
the comparison exact.

**No Fiori Elements extensions were needed.** The brief asked to prefer standard
extension mechanisms over freestyle, and to flag when one was necessary. None
was: the two-tab detail screen, the editable child table and the computed column
are all expressible with annotations plus `manifest.json` settings.

### Two things flagged for you

**The tax formula is a simplification.** We sum the rates (VAT 19 % + surcharge
5.5 % = 24.5 %) and apply the total, as the brief specified. A real German
*Solidaritätszuschlag* is charged on the *tax*, not on the base, which would give
19 % + (19 % × 5.5 %) = 20.045 %. Kept simple on purpose — the goal is to learn
where logic lives, not tax law. The note is repeated in `srv/tax-service.js`.

**"Calculated Amount" is the tax amount, not the gross.** `balance × rate ÷ 100`.
If you wanted balance-including-tax it would be `balance × (1 + rate ÷ 100)` —
exercise D1 in `docs/06-exercises.md` switches between them.

---

## Verified behaviour

The following were checked against the running service, not assumed:

- List Report renders with both value helps, and the mandatory-filter gate shows
  *"Start by providing your search or filter criteria"* until both are filled.
- Object Page renders two tabs, `Tax Rates` and `Balance Sheet Comparison`.
- Tab 1 loads the seeded rate rows (VAT Standard 19.00, Solidarity Surcharge 5.50).
- Tab 2's calculated column is correct: 1,250,000.00 × 24.5 % = **306,250.00**;
  842,300.50 × 24.5 % = **206,363.62** (correctly rounded); negative balances
  handled.
- Full draft lifecycle: `draftEdit` → add a 10 % rate → the **draft** reads
  431,250.00 while the **active** still reads 306,250.00 → `draftActivate` →
  active becomes 431,250.00.
