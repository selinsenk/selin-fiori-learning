/*******************************************************************************
 * ZI_TB_CompanyLayer  —  THE ROOT INTERFACE VIEW
 *
 * COMPARE WITH: the `entity CompanyLayers` block in db/schema.cds
 *
 * WHAT A CDS VIEW ENTITY IS
 * -------------------------
 * A CDS view entity is a SELECT statement that lives in the ABAP repository as
 * a first-class object. When you activate it, the system creates a real view on
 * the HANA database. When you `SELECT ... FROM zi_tb_companylayer` in ABAP, or
 * when OData reads it, the database does the work.
 *
 * "view ENTITY" (modern, since ~2019) vs "view" (legacy, `DEFINE VIEW` without
 * `ENTITY`): always write `define view entity` in new code. View entities have
 * stricter syntax checks, better performance, no dependent SQL view name, and
 * are the only flavour RAP fully supports.
 ******************************************************************************/

// Authorization. #NOT_REQUIRED means "this view performs no authorization check
// of its own". That is normal for INTERFACE views - the check belongs on the
// consumption view (see 03-cds-projection). Never ship #NOT_REQUIRED on a view
// that is directly exposed to a UI.
@AccessControl.authorizationCheck: #NOT_REQUIRED

// The label shown wherever this view is listed in tooling.
@EndUserText.label: 'Company Code / Layer - Interface View'

// Do not inherit annotations from the underlying table's data elements. Keeps
// interface views clean and predictable; you then annotate deliberately.
@Metadata.ignorePropagatedAnnotations: true

/*
 * `define ROOT view entity` - the word `root` matters. It declares this entity
 * to be the root of a RAP business object: the thing you lock, the thing that
 * owns children, the thing draft actions act on.
 *
 * In CAP there is no `root` keyword; the root is simply whichever entity you
 * put @odata.draft.enabled on and which owns the compositions.
 */
define root view entity ZI_TB_CompanyLayer
  as select from ztb_cmplayer

  /*--------------------------------------------------------------------------
   * COMPOSITION - "I own these children"
   *
   * Identical meaning to `taxRates : Composition of many TaxRates` in
   * db/schema.cds. Deleting the parent deletes the children; the children are
   * drafted with the parent; RAP allows creating children through the parent.
   *
   * [0..*] is the cardinality: zero or more.
   *-------------------------------------------------------------------------*/
  composition [0..*] of ZI_TB_TaxRate as _TaxRate

  /*--------------------------------------------------------------------------
   * ASSOCIATIONS - "I merely reference these"
   *
   * I_CompanyCode is a RELEASED STANDARD CDS view shipped by SAP. Reusing it
   * (instead of building a Z copy of table T001) is exactly the habit to build:
   * it already carries labels, texts, value help and the country association.
   *
   * `$projection.X` means "the field X as named in the SELECT list below", not
   * the underlying table column. This is a very common source of activation
   * errors: you must reference the ALIAS, not the raw column name.
   *-------------------------------------------------------------------------*/
  association [0..1] to I_CompanyCode  as _CompanyCode
    on $projection.CompanyCode = _CompanyCode.CompanyCode

  association [0..1] to ZI_TB_Layer    as _Layer
    on $projection.LayerID = _Layer.LayerID

  // Not a composition: G/L accounts are independent master data. Deleting a
  // company/layer combination must never delete accounting data.
  association [0..*] to ZI_TB_GLAccount as _GLAccount
    on  $projection.CompanyCode = _GLAccount.CompanyCode
    and $projection.LayerID     = _GLAccount.LayerID

{
      /*------------------------------------------------------------------------
       * THE SELECT LIST
       *
       * `key company_code as CompanyCode` renames the snake_case database column
       * to CamelCase for the outside world. This renaming is a strong SAP
       * convention: database columns are lower_snake_case, CDS fields are
       * UpperCamelCase. Follow it - every standard view does.
       *-----------------------------------------------------------------------*/
  key company_code          as CompanyCode,
  key layer_id              as LayerID,

      /*------------------------------------------------------------------------
       * THE ADMIN FIELDS, each tagged with a @Semantics annotation.
       *
       * These annotations are not documentation - they are instructions. They
       * tell RAP "this is the field to stamp with the creating user", "this is
       * the ETag field". Without them the managed runtime does not know which
       * column to fill, and activation of the behavior definition fails.
       *-----------------------------------------------------------------------*/
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,

      // The TOTAL ETag: changes when this row OR any child row changes.
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      // The LOCAL ETag: changes only when THIS row changes.
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      /*------------------------------------------------------------------------
       * EXPOSING THE ASSOCIATIONS
       *
       * An association declared above is only usable by consumers if you also
       * list it here. Forgetting this line is one of the most common beginner
       * errors - the view activates fine, but the projection view that tries to
       * use `_TaxRate` fails with "element not found".
       *-----------------------------------------------------------------------*/
      _TaxRate,
      _CompanyCode,
      _Layer,
      _GLAccount
}
