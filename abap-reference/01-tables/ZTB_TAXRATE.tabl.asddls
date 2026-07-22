@EndUserText.label : 'Tax Balance: Tax Rate Entries (Child)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #LIMITED
define table ztb_taxrate {

  key client            : abap.clnt not null;

  /*--------------------------------------------------------------------------
   * A UUID KEY, and why
   *
   * Same reasoning as in db/schema.cds: `rate_type` is free text the user can
   * edit, so it must not be part of the key. `sysuuid_x16` is a raw 16-byte
   * UUID - the standard RAP key type for child entities.
   *
   * RAP will generate the value for us. We declare that in the behavior
   * definition with:  field ( numbering : managed ) TaxRateUUID;
   * which is the exact counterpart of CAP filling `key ID : UUID` on insert.
   *-------------------------------------------------------------------------*/
  key tax_rate_uuid     : sysuuid_x16 not null;

  /*--------------------------------------------------------------------------
   * THE FOREIGN KEY BACK TO THE PARENT
   *
   * In CAP this appeared automatically as parent_companyCode / parent_layerID
   * because we used a MANAGED association (`parent : Association to one
   * CompanyLayers` with no ON condition).
   *
   * ABAP CDS has no managed associations - you always spell out both the
   * columns and the ON condition yourself. More typing, but nothing hidden.
   *-------------------------------------------------------------------------*/
  company_code          : bukrs not null;
  layer_id              : ztb_layer_id not null;

  /*--------------------------------------------------------------------------
   * THE PAYLOAD
   *
   * ztb_rate_value is a custom data element over a DEC(5,2) domain.
   *
   * NEVER use abap.fltp (floating point) for rates or money. Use:
   *   abap.dec  - packed decimal, exact. For rates, quantities, factors.
   *   abap.curr - packed decimal + it MUST be paired with a currency field.
   * This is the same warning as in db/schema.cds, and it matters just as much
   * on both sides.
   *-------------------------------------------------------------------------*/
  rate_type             : ztb_rate_type;
  rate_value            : ztb_rate_value;

  /*--------------------------------------------------------------------------
   * Only the LOCAL ETag here. The child does not need its own total ETag,
   * because locking and the total ETag are inherited from the parent - see
   * `lock dependent by _CompanyLayer` in the behavior definition.
   *-------------------------------------------------------------------------*/
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}

/*******************************************************************************
 * Draft table ZTB_TAXRATE_D is generated the same way as for the root.
 * Every draft-enabled entity in the business object gets its own draft table.
 ******************************************************************************/
