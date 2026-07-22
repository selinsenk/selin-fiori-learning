/*******************************************************************************
 * ZI_TB_TaxRate  —  THE CHILD INTERFACE VIEW
 *
 * COMPARE WITH: the `entity TaxRates` block in db/schema.cds
 ******************************************************************************/

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tax Rate Entry - Interface View'
@Metadata.ignorePropagatedAnnotations: true

// Note: NO `root` keyword. There is exactly one root per business object.
define view entity ZI_TB_TaxRate
  as select from ztb_taxrate

  /*--------------------------------------------------------------------------
   * `association TO PARENT` - a special kind of association
   *
   * This is not just any association back to ZI_TB_CompanyLayer; the words
   * `to parent` tell RAP that this entity is a composition child and that the
   * target is its owner. RAP needs this to know how to lock, how to authorize,
   * and how to draft the child together with the parent.
   *
   * A composition on the parent side MUST be matched by an `association to
   * parent` on the child side. If you write one without the other, activation
   * fails. CAP expresses the same pair as:
   *      parent side: taxRates : Composition of many TaxRates on taxRates.parent = $self
   *      child side : parent   : Association to one CompanyLayers
   *-------------------------------------------------------------------------*/
  association to parent ZI_TB_CompanyLayer as _CompanyLayer
    on  $projection.CompanyCode = _CompanyLayer.CompanyCode
    and $projection.LayerID     = _CompanyLayer.LayerID

{
  key tax_rate_uuid         as TaxRateUUID,

      // The parent key fields. They are ordinary (non-key) fields here, because
      // the UUID alone identifies the row - but they must be present so the
      // association to the parent has something to join on.
      company_code          as CompanyCode,
      layer_id              as LayerID,

      rate_type             as RateType,
      rate_value            as RateValue,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _CompanyLayer
}
