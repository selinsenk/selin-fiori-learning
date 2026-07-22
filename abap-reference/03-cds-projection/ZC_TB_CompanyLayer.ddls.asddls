/*******************************************************************************
 * ZC_TB_CompanyLayer  —  THE CONSUMPTION (PROJECTION) VIEW
 *
 * COMPARE WITH: `entity CompanyLayers as projection on db.CompanyLayers`
 *               in srv/tax-service.cds
 *
 * The word `projection` is literal in both worlds: this view does not re-select
 * from a table, it projects an existing view - picking a subset of its fields
 * and adding app-specific meaning.
 ******************************************************************************/

// #CHECK, not #NOT_REQUIRED. THIS is the layer where authorization is enforced,
// because this is the layer the outside world reaches. #CHECK means "apply the
// access control (DCL) object with the same name as this view".
@AccessControl.authorizationCheck: #CHECK

@EndUserText.label: 'Company Code / Layer - Consumption View'

/*
 * @Metadata.allowExtensions: true is REQUIRED if you want to put the UI
 * annotations in a separate metadata extension file (which we do - see
 * 04-metadata-extension/). Without it, ADT rejects the .ddlx.
 *
 * You could instead write the @UI annotations inline in this file. SAP's own
 * guidance is to separate them, for two reasons:
 *   1. the data model stops being cluttered by presentation concerns
 *   2. metadata extensions have LAYERS (#CORE / #INDUSTRY / #PARTNER /
 *      #CUSTOMER), so a customer can adjust the UI of an SAP-delivered app
 *      without modifying it
 * Our CAP app makes the same separation: tax-service.cds vs annotations.cds.
 */
@Metadata.allowExtensions: true

define root view entity ZC_TB_CompanyLayer
  /*--------------------------------------------------------------------------
   * PROVIDER CONTRACT - the line that makes this a TRANSACTIONAL app
   *
   * `transactional_query` promises: this view is the read side of a RAP
   * business object, and a behavior definition will supply the write side.
   * It switches on the checks that guarantee the view is RAP-compatible
   * (keys must match the underlying entity, no aggregation, etc).
   *
   * The alternatives you will meet:
   *   provider contract transactional_query      -> RAP transactional (this)
   *   provider contract analytical_query         -> analytics / KPI tiles
   *   (none)                                     -> a plain reusable view
   *-------------------------------------------------------------------------*/
  provider contract transactional_query
  as projection on ZI_TB_CompanyLayer
{
  key CompanyCode,
  key LayerID,

      /*------------------------------------------------------------------------
       * PATH EXPRESSIONS - flattening associated data into this view
       *
       * `_CompanyCode.CompanyCodeName` reaches through the association and pulls
       * the name in as a normal-looking field. The database turns it into a LEFT
       * OUTER JOIN. This is one of ABAP CDS's nicest features.
       *
       * We do the same thing in Fiori Elements annotations with the path
       * `company.name` - but there it happens in the UI layer via $expand,
       * whereas here it happens in the database. Doing it here is usually
       * cheaper and always available to non-UI consumers.
       *-----------------------------------------------------------------------*/
      _CompanyCode.CompanyCodeName as CompanyName,
      _CompanyCode.Country         as Country,
      _CompanyCode._Country._Text.CountryName as CountryName : localized,
      _Layer.LayerDescription      as LayerDescription,

      // The admin fields must be projected too - RAP needs them at this layer
      // as well, because the behavior projection refers to them.
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.lastChangedBy: true
      LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,

      /*------------------------------------------------------------------------
       * REDIRECTION - a concept with no CAP equivalent, so read carefully.
       *
       * ZI_TB_CompanyLayer._TaxRate points at the INTERFACE view ZI_TB_TaxRate.
       * But the service must expose the CONSUMPTION view ZC_TB_TaxRate, which
       * has the UI annotations. `redirected to` rewires the association so it
       * lands on the consumption view instead.
       *
       * Rule of thumb: in a projection view, EVERY association you expose must
       * be redirected to the corresponding projection view, or the service will
       * leak interface-layer entities into your OData metadata.
       *
       * `composition child` is used for compositions; plain `redirected to` for
       * ordinary associations.
       *-----------------------------------------------------------------------*/
      _TaxRate   : redirected to composition child ZC_TB_TaxRate,
      _GLAccount : redirected to ZC_TB_GLAccount,

      // These point at released SAP views that are already consumption-ready,
      // so no redirection is needed.
      _CompanyCode,
      _Layer
}
