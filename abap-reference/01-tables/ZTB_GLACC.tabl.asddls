@EndUserText.label : 'Tax Balance: G/L Account Balances (Read-Only)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #LIMITED
define table ztb_glacc {

  key client       : abap.clnt not null;
  key company_code : bukrs not null;
  key layer_id     : ztb_layer_id not null;
  key gl_account   : saknr not null;   // SAKNR = the standard G/L account data element

  account_name     : ztb_account_name;

  /*--------------------------------------------------------------------------
   * CURRENCY AMOUNTS IN ABAP - a rule with no equivalent in most languages
   *
   * A field typed `abap.curr` MUST be accompanied by a currency key field, and
   * the CDS view on top must say which one via
   *      @Semantics.amount.currencyCode: 'Currency'
   *
   * Why: abap.curr stores the amount WITHOUT knowing its decimal places. The
   * currency decides them - JPY has 0 decimals, EUR has 2, KWD has 3. Store
   * 1000 in a curr field and it means 10.00 EUR but 1000 JPY. Get the pairing
   * wrong and your numbers are silently off by a factor of 100. This is a
   * genuine, common production bug in SAP finance code.
   *
   * The CAP counterpart is @Measures.ISOCurrency: currency in db/schema.cds -
   * same pairing, enforced less strictly.
   *-------------------------------------------------------------------------*/
  balance_amount   : abap.curr(15,2);
  currency         : waers;

}

/*******************************************************************************
 * IN A REAL S/4HANA SYSTEM YOU WOULD PROBABLY NOT CREATE THIS TABLE AT ALL.
 *
 * G/L balances already exist. They live in ACDOCA (the Universal Journal - the
 * single line-item table that S/4HANA introduced) and are exposed by released
 * CDS views such as I_GLAccountLineItem / I_GLAccountBalance.
 *
 * So the realistic version of ZI_TB_GLAccount would select from those instead
 * of from a custom table, and this file would not exist. We create a custom
 * table here purely so the example is self-contained and mirrors the CSV seed
 * data in db/data/.
 *
 * The habit to learn: BEFORE creating a Z table, search for a released standard
 * CDS view that already has the data. Use transaction/app "View Browser" or
 * ADT's "Open CDS View". Reusing standard views is how you get a system that
 * survives upgrades.
 ******************************************************************************/
