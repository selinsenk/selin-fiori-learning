@EndUserText.label : 'Tax Balance: Accounting Layers (Code List)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztb_layer {

  key client   : abap.clnt not null;
  key layer_id : ztb_layer_id not null;
  description  : ztb_layer_desc;

}

/*******************************************************************************
 * NOTE THE DELIVERY CLASS: #C, not #A
 *
 * deliveryClass controls how data in this table behaves during client copies
 * and system upgrades. The ones you meet in practice:
 *
 *   #A  Application data (master + transaction data). Our other three tables.
 *       Not transported; it is business data that lives in each system.
 *   #C  Customizing. Configuration that IS transported from DEV to QA to PROD
 *       in a transport request. Code lists like this belong here.
 *   #L  Temporary data.
 *   #S  System table delivered by SAP.
 *
 * Why it matters: if you put a code list in an #A table, the entries you
 * carefully created in the development system will NOT arrive in production,
 * and your app will show empty dropdowns there. Choosing #A vs #C wrongly is a
 * classic first-project mistake.
 *
 * There is no CAP equivalent - in CAP, db/data/*.csv files are simply loaded
 * wherever the app is deployed.
 ******************************************************************************/
