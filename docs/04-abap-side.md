# 04 — The ABAP side: reading `/abap-reference`

This page is the guided tour of the ABAP folder. Read it with the files open.

## ABAP survival syntax

Enough to read the files without stumbling.

```abap
" a comment starts with a double quote
* a comment can also start with an asterisk in column 1

DATA lv_count TYPE i.               " a variable. lv_ = local variable (convention)
DATA(lv_new)  = 5.                  " inline declaration, modern style

lv_count = lv_count + 1.            " every statement ends with a PERIOD.

IF lv_count > 3 AND lv_name IS INITIAL.   " IS INITIAL = "is the default value"
  " ...                                    " there is no NULL in ABAP
ELSEIF lv_count = 0.
ELSE.
ENDIF.

LOOP AT lt_table INTO DATA(ls_row).  " lt_ = internal table, ls_ = structure
ENDLOOP.

SELECT rate_type, rate_value         " ABAP SQL. @ marks ABAP variables.
  FROM ztb_taxrate
  WHERE company_code = @lv_bukrs
  INTO TABLE @DATA(lt_rates).
```

Two rules that catch everyone:

- **Spaces around parentheses and operators are mandatory.**
  `round( val = x dec = 2 )` — not `round(val=x,dec=2)`.
- **Naming prefixes are conventions, not syntax**, but everyone follows them:
  `lv_` local variable, `ls_` local structure, `lt_` local table, `iv_`/`is_`/`it_`
  importing, `ev_`/`et_` exporting, `rv_`/`rt_` returning, `gv_` global,
  `mv_`/`mt_` member (instance attribute).

Method parameters have directions: `IMPORTING` (in), `EXPORTING` (out),
`CHANGING` (in and out), `RETURNING` (a single result, usable in expressions).

## The object chain

To build one Fiori app in S/4HANA you create roughly a dozen objects. They stack:

```
                    Service Binding      ZUI_TB_TAXBALANCE_O4     ← the URL
                            ▲
                    Service Definition   ZUI_TB_TAXBALANCE        ← what is exposed
                            ▲
   Metadata Ext. ──►  Projection Views    ZC_TB_*                 ← app-specific shape
   (.ddlx = the UI)         ▲                    ▲
                     Interface Views      ZI_TB_*             Behavior Definition
                            ▲                                  ZI_/ZC_*.bdef
                     Database Tables      ZTB_*                     ▲
                                                            Behavior Pool ZBP_*
                                                            (+ helper classes ZCL_*)
```

Compare with CAP's two files (`db/schema.cds`, `srv/tax-service.cds`) plus one
handler (`srv/tax-service.js`). ABAP is more ceremonious — but each layer is
separately reusable, transportable and access-controlled, which is what a system
running a whole corporation needs.

## The five things worth studying most

### 1. `ZI_TB_CompanyLayer.ddls` — associations and compositions

Read it against the `CompanyLayers` entity in `db/schema.cds`. Same three
relationships, same distinction between owning children (composition) and merely
referencing (association). The visible difference is that ABAP CDS always makes
you write the `ON` condition, and requires `$projection.` when referring to your
own aliased fields.

### 2. `ZC_TB_GLAccount.ddls` — the virtual element

```abap
@ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_TB_GLACC_VE'
virtual CalculatedAmount : ztb_amount,
```

versus CAP:

```cds
virtual calculatedAmount : Decimal(15,2)
```

Identical keyword, identical concept, identical limitation (**not sortable or
filterable**, because the database cannot see the field). The difference is that
ABAP names the implementing class in the model, while CAP finds the handler by
file-name convention.

The file ends with a comparison of the four ways to compute a derived field in
ABAP (virtual element / CDS expression / table function / determination) and when
each is the right choice. That decision comes up constantly in real work.

### 3. `ZC_TB_CompanyLayer.ddlx` — the UI, in ABAP

This is the closest thing in the repository to a Rosetta Stone. Read it line by
line against `srv/annotations.cds`. The terms are the same OData vocabulary in
both; only the spelling differs:

| CAP CDS | ABAP CDS |
|---|---|
| `UI.LineItem: [{Value: x}]` | `@UI.lineItem: [{ position: 10 }]` above field `x` |
| `UI.SelectionFields: [x, y]` | `@UI.selectionField: [{ position: 10 }]` above each |
| `$Type: 'UI.CollectionFacet'` | `type: #COLLECTION` |
| `Target: 'taxRates/@UI.LineItem'` | `type: #LINEITEM_REFERENCE, targetElement: '_TaxRate'` |
| array order = screen order | explicit `position: 10, 20, 30` |
| `Common.ValueList: {...}` | `@Consumption.valueHelpDefinition: [{...}]` |
| `Capabilities.FilterRestrictions.RequiredProperties` | `@Consumption.filter.mandatory: true` |

The ABAP version is often *shorter*, because SAP-released value-help views carry
their own key and text annotations, so you point at the view and stop.

### 4. `ZI_TB_CompanyLayer.bdef` — the behavior definition

There is no CAP file that looks like this, because CAP scatters the same
information across annotations. The mapping:

| RAP behavior definition | CAP equivalent |
|---|---|
| `with draft;` | `@odata.draft.enabled` |
| `update;` present, `create;`/`delete;` absent | `@Capabilities.InsertRestrictions.Insertable: false` etc. |
| `field ( readonly ) CompanyCode` | `@readonly` on the element |
| `field ( mandatory ) RateType` | `@Common.FieldControl: #Mandatory` |
| `field ( numbering : managed ) TaxRateUUID` | CAP auto-fills `key ID : UUID` |
| `association _TaxRate { create; }` | the composition itself implies it |
| `draft action Edit/Activate/Discard` | generated automatically |
| `validation ... on save` | `this.before(['CREATE','UPDATE'], ...)` |
| `lock master` / `etag master` | draft locks + `@odata.etag` |

Notice that RAP makes you state things CAP infers. That is a deliberate trade:
RAP is explicit and checkable at activation time; CAP is terse and figures it out.

### 5. `ZCL_TB_GLACC_VE.clas.abap` — the handler

Read it against `srv/tax-service.js`. The two-phase structure is the same:

| ABAP method | CAP hook | Purpose |
|---|---|---|
| `GET_CALCULATION_INFO` | `this.before('READ', ...)` | "also read these stored fields, I need them" |
| `CALCULATE` | `this.after('READ', ...)` | "here are the rows, fill in the virtual field" |

Both cache per company/layer to avoid re-reading the rates for every row — in
ABAP because "SELECT inside LOOP" is the classic performance sin, in JavaScript
because each `SELECT` is an async round-trip.

The comment block at the end of that file is the most important part: it explains
that a plain `SELECT` reads the **active** table and would therefore ignore the
user's unsaved draft, and that the correct RAP answer is `READ ENTITIES ... 
%is_draft = if_abap_behv=>mk-on` (EML), not reading the draft table directly.
That is the same bug we actually hit and fixed in CAP — see the `isDraftRequest`
comment in `srv/tax-service.js`.

## What is NOT in the ABAP folder, and would be in real life

- **CDS access controls (`.dcl`)** — row-level authorization. Every finance app
  needs one restricting company codes to what the user is authorized for.
- **Number ranges** — for anything with a business document number.
- **Message class (T100)** — so validation messages can be translated. Our
  behavior pool hard-codes English strings, which no reviewer would accept.
- **Transport requests** — every object above belongs to one.
- **Extensibility annotations** — if the app is meant to be extended by others.
