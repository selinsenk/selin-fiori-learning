# The old way: SEGW / SAP Gateway — and how to recognise it

Everything in folders 01–07 is **RAP** (ABAP RESTful Application Programming
Model), the current approach. But RAP only arrived around 2018–2019, and most
companies still run plenty of code written the previous way. You will meet it.
This page is so you can recognise it, not so you can write it.

## The two eras at a glance

| | Classic Gateway (2011 → ~2019) | RAP (2019 → today) |
|---|---|---|
| Where you build it | Transaction **SEGW** (a SAP GUI tool) | **ADT** in Eclipse (source-code based) |
| The model is | clicked together in a tree UI | written as CDS source files |
| Protocol | OData **V2** | OData **V4** (V2 possible) |
| Business logic | redefine methods in a generated `*_DPC_EXT` class | behavior definition + behavior pool |
| Draft support | none built in — hand-rolled or via BOPF | built in (`with draft`) |
| Transportable as text / diffable in git | poorly | yes |
| Testability | hard | ABAP Unit + test doubles designed in |

## What the objects were called

When you open an old project in SEGW you see four generated classes:

| Object | Role |
|---|---|
| `ZCL_..._MPC` | **M**odel **P**rovider **C**lass — the entity types and properties. Generated; never edit. |
| `ZCL_..._MPC_EXT` | Your subclass of the above. Here you added annotations by hand, in ABAP code. |
| `ZCL_..._DPC` | **D**ata **P**rovider **C**lass — the runtime. Generated; never edit. |
| `ZCL_..._DPC_EXT` | Your subclass. **This is where all the real work went.** |

Inside `_DPC_EXT` you redefined methods with names built from the entity set:

```abap
METHOD companylayerset_get_entityset.   " the GET for a list  -> our List Report
METHOD companylayerset_get_entity.      " the GET for one row -> our Object Page
METHOD taxrateset_create_entity.        " the POST            -> adding a rate
METHOD taxrateset_update_entity.        " the PATCH
METHOD taxrateset_delete_entity.        " the DELETE
```

Each one received the request, and you wrote the `SELECT`, the paging, the
filtering — by hand. Reading `io_tech_request_context->get_filter( )` and
translating OData `$filter` into a `WHERE` clause was normal, tedious work.

**That is the single biggest difference.** In RAP (and in CAP) you declare the
model and the framework generates all of that. In SEGW you wrote it, per entity
set, per project, forever.

## Annotations in the classic world

There was no metadata extension file. UI annotations were either:

1. written in ABAP inside `MPC_EXT`, appending to a vocabulary annotation table —
   verbose and easy to get wrong; or
2. put in a **CDS view with `@OData.publish: true`**, which was the transitional
   middle era: you got CDS annotations, but the service was still OData V2 and
   still needed activating in transaction `/IWFND/MAINT_SERVICE`.

If you see `@OData.publish: true` in a CDS view at work, that is the middle era.
It is deprecated for new development — RAP service definition + binding replaces it.

## Registering the service

A classic Gateway service was not reachable until you registered it in the
frontend server:

- `/IWFND/MAINT_SERVICE` — add the service, assign a system alias
- `/IWFND/GW_CLIENT` — a built-in test client for firing requests at it
- `/IWFND/ERROR_LOG` — where you found out why it returned 500

RAP replaced this with the **service binding**'s Publish button (see
`../06-service/BINDING.md`), though `/IWFND/ERROR_LOG` is still where runtime
errors surface, and is still the first place to look when a Fiori app breaks.

## How this app would have looked

The same two screens were achievable, but:

- **Draft would not exist.** The Tab 1 table would save each row immediately on
  change, or you would build your own "edit buffer" in the DPC. The
  Edit/Save/Cancel pattern the user expects came free with RAP and had to be
  faked before it.
- **The calculated column** would be filled inside
  `glaccountset_get_entityset` — you would SELECT the accounts, SELECT the tax
  rates, loop, and fill the field before returning. Actually *closer* in spirit
  to our CAP handler in `srv/tax-service.js` than the RAP virtual element is.
- **The mandatory filter gate** would be code: read the filter context, and if
  Company Code is missing, `RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception`.

## What to take away

If you join a team and see `SEGW`, `DPC_EXT`, `MPC_EXT` — that is the old model,
still perfectly functional, and a large amount of production SAP runs on it.
If you see `.ddls`, `.bdef`, `.srvd` files in Eclipse — that is RAP.

New development should be RAP. The Fiori Elements frontend you built in this
project is **unchanged either way** — that is the point of OData being a
contract. A List Report does not know or care which ABAP generation is behind
the URL.
