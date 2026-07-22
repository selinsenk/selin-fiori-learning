/*******************************************************************************
 * ZI_TB_GLAccount  —  THE READ-ONLY BALANCE DATA
 *
 * COMPARE WITH: the `entity GLAccounts` block in db/schema.cds
 *
 * Note there is NO virtual CalculatedAmount here. Interface views describe what
 * is stored; the calculated field is an app-specific presentation concern, so it
 * belongs on the consumption view (03-cds-projection/ZC_TB_GLAccount).
 * Keeping derived fields out of interface views is good discipline: it means
 * other apps can reuse this view without inheriting our tax logic.
 ******************************************************************************/

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'G/L Account Balance - Interface View'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_TB_GLAccount
  as select from ztb_glacc

  // I_GLAccount is SAP's released view over the chart of accounts. Associating
  // to it gives consumers the official account long text, account group and
  // blocking indicators without us copying any of it.
  association [0..1] to I_GLAccount   as _GLAccountMaster
    on $projection.GLAccount = _GLAccountMaster.GLAccount

  association [0..1] to I_CompanyCode as _CompanyCode
    on $projection.CompanyCode = _CompanyCode.CompanyCode

{
  key company_code   as CompanyCode,
  key layer_id       as LayerID,
  key gl_account     as GLAccount,

      account_name   as AccountName,

      /*------------------------------------------------------------------------
       * The currency pairing, declared. Both annotations are required:
       *   @Semantics.amount.currencyCode - "my currency lives in field Currency"
       *   @Semantics.currencyCode        - "I am a currency key"
       * Get these right and every consumer (Fiori, ALV, Excel export, analytics)
       * formats the amount correctly with no further work.
       *
       * CAP counterpart: @Measures.ISOCurrency: currency
       *-----------------------------------------------------------------------*/
      @Semantics.amount.currencyCode: 'Currency'
      balance_amount as BalanceAmount,

      @Semantics.currencyCode: true
      currency       as Currency,

      _GLAccountMaster,
      _CompanyCode
}
