/*******************************************************************************
 * ZC_TB_GLAccount  —  THE VIRTUAL ELEMENT LIVES HERE
 *
 * THIS IS THE FILE TO COMPARE WITH srv/tax-service.js.
 *
 * In CAP we declared `virtual calculatedAmount` in the model and filled it in an
 * `after('READ')` handler. ABAP does exactly the same thing, with exactly the
 * same word - `virtual` - but the wiring is explicit: an annotation names the
 * class that will fill it.
 ******************************************************************************/

@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'G/L Account with Calculated Amount'
@Metadata.allowExtensions: true

define view entity ZC_TB_GLAccount
  as projection on ZI_TB_GLAccount
{
  key CompanyCode,
  key LayerID,
  key GLAccount,

      AccountName,

      @Semantics.amount.currencyCode: 'Currency'
      BalanceAmount,

      @Semantics.currencyCode: true
      Currency,

      /*------------------------------------------------------------------------
       * THE VIRTUAL ELEMENT
       *
       * `virtual` = there is no column for this anywhere. The database knows
       * nothing about it. It appears in the OData $metadata, the UI can display
       * it, and an ABAP class computes it row by row at read time.
       *
       * @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_TB_GLACC_VE'
       *   names the class. The 'ABAP:' prefix is required. The class must
       *   implement interface IF_SADL_EXIT_CALC_ELEMENT_READ.
       *   -> see ../07-classes/ZCL_TB_GLACC_VE.clas.abap
       *
       * THE LIMITATION YOU MUST KNOW ABOUT:
       * A virtual element cannot be used in a WHERE clause or an ORDER BY that
       * the database executes, because the database cannot see it. Concretely,
       * in the Fiori app the user CANNOT sort or filter by Calculated Amount
       * (the framework will either refuse or, worse, sort only the current page).
       * If you need sorting/filtering on a derived value, you must materialise
       * it - compute it during posting and store it in a real column.
       *
       * Our CAP implementation has precisely the same limitation for precisely
       * the same reason: `virtual calculatedAmount` is filled after the SELECT
       * has already run, so SQL cannot order by it.
       *-----------------------------------------------------------------------*/
      @EndUserText.label: 'Calculated Amount'
      @Semantics.amount.currencyCode: 'Currency'
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_TB_GLACC_VE'
      virtual CalculatedAmount : ztb_amount,

      _GLAccountMaster,
      _CompanyCode
}

/*******************************************************************************
 * THE OTHER THREE WAYS TO DO THIS IN ABAP - and when to pick each
 *
 * 1. VIRTUAL ELEMENT (this file)
 *    Logic in ABAP, runs per read, sees the draft.
 *    + can do anything ABAP can do; + reads other tables freely
 *    - not filterable/sortable; - runs for every row of every read
 *    Use when: the value depends on data outside the row, or on user context.
 *
 * 2. CDS CALCULATED FIELD - just an expression in the SELECT list, e.g.
 *         BalanceAmount * :p_Rate / 100 as CalculatedAmount
 *    + runs in the database, fast, fully filterable and sortable
 *    - only simple SQL expressions; cannot read a whole other table and sum it
 *    Use when: the formula uses fields of the same row (or a joined row).
 *
 * 3. CDS TABLE FUNCTION - an AMDP (ABAP-Managed Database Procedure) written in
 *    SQLScript, running inside HANA.
 *    + full SQL power at database speed
 *    - HANA-only, harder to debug and to test
 *    Use when: heavy set-based calculation over millions of rows.
 *
 * 4. A DETERMINATION storing the result in a real field (see 05-behavior/).
 *    + fully filterable/sortable, computed once
 *    - the stored value can go stale if its inputs change elsewhere
 *    Use when: users must sort/filter by it, or it must appear in reports.
 *
 * For OUR case a virtual element is right: the value is the sum of rows in
 * another table, and it must change the instant the user edits a draft.
 ******************************************************************************/
