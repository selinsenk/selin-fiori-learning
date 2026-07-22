@EndUserText.label : 'Tax Balance: Company Code / Layer (Root)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #LIMITED
define table ztb_cmplayer {

  /*--------------------------------------------------------------------------
   * THE CLIENT FIELD - the most important thing to understand about SAP tables
   *
   * Almost every SAP table starts with `client`. One physical S/4HANA system
   * hosts several logically separate "clients" (client 100 = production data,
   * client 200 = training data, ...). Every row belongs to exactly one client,
   * and ABAP's OpenSQL automatically adds `WHERE mandt = sy-mandt` to your
   * queries, so you almost never mention it yourself.
   *
   * There is no equivalent in our CAP app - CAP's multitenancy works
   * differently (separate database schemas per tenant, not a key column).
   *-------------------------------------------------------------------------*/
  key client            : abap.clnt not null;

  /*--------------------------------------------------------------------------
   * THE BUSINESS KEY
   *
   * Note the TYPES. `bukrs` is not "a 4-character string" - it is a DATA
   * ELEMENT, an SAP-delivered named type that carries with it:
   *   - the technical type (CHAR 4)
   *   - the field label in every installed language ("Company Code")
   *   - the F4 search help (the value help dropdown!)
   *   - the check table (T001), which enforces referential integrity
   *
   * This is why SAP developers reuse standard data elements obsessively: you
   * inherit labels, help texts and value helps for free. In CAP we had to write
   * @title and @Common.ValueList by hand to get the same effect.
   *
   * ZTB_LAYER_ID is a custom data element you would create yourself
   * (see 01-tables/DATA-ELEMENTS.md).
   *-------------------------------------------------------------------------*/
  key company_code      : bukrs not null;
  key layer_id          : ztb_layer_id not null;

  /*--------------------------------------------------------------------------
   * THE RAP ADMINISTRATIVE FIELDS
   *
   * These five fields are not decoration - the RAP framework REQUIRES them for
   * a "managed" business object with draft, and fills them for you:
   *
   *   created_by / created_at         : who inserted the row, and when
   *   last_changed_by / last_changed_at : who last changed it (the TOTAL ETag)
   *   local_last_changed_at           : the LOCAL ETag
   *
   * WHAT IS AN ETAG? It is optimistic locking. When the UI reads a row it also
   * receives that row's timestamp. When it later writes, it sends the timestamp
   * back. If it no longer matches, someone else changed the row in between and
   * the write is rejected instead of silently overwriting their work.
   *
   * "Total" vs "local": local = this row changed. Total = this row OR any of its
   * children changed. The tax rate table below shares the parent's total ETag.
   *
   * CAP has the same concept via the `managed` aspect from @sap/cds/common
   * (createdAt, createdBy, modifiedAt, modifiedBy). We left it out of our CAP
   * model to keep the first read simple - but a real service would include it.
   *-------------------------------------------------------------------------*/
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}

/*******************************************************************************
 * THE DRAFT TABLE
 *
 * Because this business object is draft-enabled, it needs a SECOND table to
 * hold unsaved drafts - the shadow table. You do NOT hand-write it: in ADT you
 * right-click the behavior definition and use the quick-fix
 *
 *     "Create draft table ZTB_CMPLAYER_D"
 *
 * and ADT generates it with the same fields plus the draft administrative
 * fields (DraftUUID, DraftEntityCreationDateTime, DraftEntityLastChangeDateTime,
 * DraftAdministrativeDataUuid, ...).
 *
 * This is precisely what CAP creates silently when you write
 * @odata.draft.enabled - it makes a CompanyLayers.drafts table behind your back.
 * Remember the debugging discovery in srv/tax-service.js: CAP rewrites queries
 * to point at `...CompanyLayers.drafts`. Same mechanism, same idea.
 ******************************************************************************/
