/*******************************************************************************
 * ZC_TB_TaxRate  —  CONSUMPTION VIEW FOR THE EDITABLE CHILD
 *
 * COMPARE WITH: `entity TaxRates as projection on db.TaxRates`
 *               in srv/tax-service.cds
 ******************************************************************************/

@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Tax Rate Entry - Consumption View'
@Metadata.allowExtensions: true

define view entity ZC_TB_TaxRate
  as projection on ZI_TB_TaxRate
{
  key TaxRateUUID,

      CompanyCode,
      LayerID,
      RateType,
      RateValue,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,

      // Redirect back up to the parent's consumption view. `to parent` is kept.
      _CompanyLayer : redirected to parent ZC_TB_CompanyLayer
}

/*******************************************************************************
 * WHY IS THERE NO `provider contract transactional_query` HERE?
 *
 * Only the ROOT of the business object declares the provider contract. Child
 * projection views inherit their contract from the root they are redirected
 * from. Adding it here would be an activation error.
 *
 * Analogy in our CAP service: we wrote @odata.draft.enabled only on
 * CompanyLayers, never on TaxRates - draft flows down the composition. Same
 * principle, expressed differently.
 ******************************************************************************/
