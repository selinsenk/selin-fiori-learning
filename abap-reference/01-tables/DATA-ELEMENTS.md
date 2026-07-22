# The custom domains and data elements this project needs

Before the tables in this folder will activate, these DDIC objects must exist.
In ADT you create them with **File → New → Other ABAP Repository Object →
Domain / Data Element**.

## The three-layer DDIC type system

This layering has no equivalent in CAP or in most programming languages, and it
is worth understanding because it is why SAP screens are consistent.

```
DOMAIN            ZTB_LAYER_ID        technical only: CHAR(2), fixed values, conversion routine
   ↓ used by
DATA ELEMENT      ZTB_LAYER_ID        semantics: labels in every language, F4 help, documentation
   ↓ used by
TABLE FIELD       ztb_cmplayer-layer_id
```

- A **domain** answers *"what does this value look like?"* — length, type,
  allowed values, whether leading zeros are added.
- A **data element** answers *"what does this value mean?"* — its short/medium/
  long/heading labels, its search help, its F1 documentation.
- A **table field** just says *"use that data element here"*.

The payoff: define the label once on the data element, and **every** table,
CDS view, ALV grid and Fiori field that uses it shows the same translated label
automatically. In our CAP model we had to repeat `@title: 'Layer ID'` by hand.

## Objects to create

| Data element | Domain | Type | Label | Notes |
|---|---|---|---|---|
| `ZTB_LAYER_ID` | `ZTB_LAYER_ID` | CHAR(2) | Layer ID | Fixed values `01`/`02`/`03` may be set on the domain — that alone produces a dropdown in the UI |
| `ZTB_LAYER_DESC` | `ZTB_LAYER_DESC` | CHAR(60) | Layer Description | |
| `ZTB_RATE_TYPE` | `ZTB_RATE_TYPE` | CHAR(40) | Rate Type | Free text on purpose — no fixed values, per the project brief |
| `ZTB_RATE_VALUE` | `ZTB_RATE_VALUE` | DEC(5,2) | Rate Value (%) | **Not** FLTP |
| `ZTB_ACCOUNT_NAME` | `ZTB_ACCOUNT_NAME` | CHAR(60) | Account Name | |
| `ZTB_AMOUNT` | `ZTB_AMOUNT` | CURR(15,2) | Amount | Used as the calculation result type |

## Standard objects reused (do NOT create these)

| Object | What it is |
|---|---|
| `BUKRS` | Company Code — data element, check table `T001`, search help included |
| `SAKNR` | G/L Account Number |
| `WAERS` | Currency Key — check table `TCURC` |
| `SYSUUID_X16` | 16-byte UUID, the standard RAP key type |
| `ABP_CREATION_USER`, `ABP_CREATION_TSTMPL`, `ABP_LASTCHANGE_USER`, `ABP_LASTCHANGE_TSTMPL`, `ABP_LOCINST_LASTCHANGE_TSTMPL` | The RAP administrative field types |

Reusing `BUKRS` rather than inventing `ZTB_COMPANY` is the single easiest way to
make a custom app feel like part of the standard system: you inherit its label,
its documentation, and its value help in 40 languages.
