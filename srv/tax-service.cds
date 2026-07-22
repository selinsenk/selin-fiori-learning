/******************************************************************************
 * srv/tax-service.cds  —  THE SERVICE DEFINITION
 *
 * WHAT THIS FILE IS
 * -----------------
 * db/schema.cds said WHAT DATA EXISTS.
 * This file says WHAT THE OUTSIDE WORLD IS ALLOWED TO SEE, under which names,
 * at which URL. That is exactly what an OData service is.
 *
 * Once this file exists, a real HTTP API appears at
 *     http://localhost:4004/odata/v4/tax-balance/
 * with, for example:
 *     .../CompanyLayers            <- list of rows  (an "entity set")
 *     .../CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)
 *     .../$metadata                <- machine-readable description of everything
 *
 * WHY A SEPARATE LAYER AT ALL?
 * ----------------------------
 * Because your database model and your API are different things. The database
 * may hold 40 fields; the API exposes 12. The database table is called
 * SKB1; the API calls it GLAccounts. This separation is universal in SAP:
 *
 *   CAP (here)            ABAP / RAP  (../abap-reference/)
 *   ------------------    -----------------------------------------------
 *   db/schema.cds         DDIC tables + ZI_* interface CDS views
 *   srv/tax-service.cds   ZC_* projection views + ZUI_*.srvd Service Definition
 *   (the URL itself)      ZUI_*.srvb Service Binding  <- this is what makes it OData
 *
 * ABAP has ONE extra step we do not: in ABAP the Service Definition says
 * "expose these entities", and a separate Service *Binding* says "publish it as
 * OData V4 UI". In CAP, `service { ... }` does both at once.
 ******************************************************************************/

// `using` = import. We pull in the namespace from db/schema.cds and give it the
// short alias `db` so we can write db.CompanyLayers instead of the long name.
using sap.learning.taxbalance as db from '../db/schema';


// @path sets the URL. Without it CAP would derive one from the service name.
service TaxBalanceService @(path: '/odata/v4/tax-balance') {

  /****************************************************************************
   * THE ROOT ENTITY - and the single most important annotation in this project
   ****************************************************************************/

  // ---- @odata.draft.enabled -------------------------------------------------
  // This one line turns on SAP's DRAFT concept, and you need to understand it
  // because every modern S/4HANA transactional app works this way.
  //
  // WITHOUT draft: you type in a field, it saves straight to the database.
  // WITH draft:
  //     1. You press EDIT       -> a private *copy* of the row is created
  //                                (in shadow tables, only you can see it)
  //     2. You type freely      -> everything is stored in that copy, so your
  //                                work survives a browser crash or a logout
  //     3. You press SAVE       -> the copy is validated and written over the
  //                                real ("active") row, then the copy is deleted
  //     4. Or you press CANCEL  -> the copy is thrown away, nothing changed
  //
  // That is why every URL in this app carries `IsActiveEntity=true|false`:
  // true = the real saved row, false = your personal draft copy.
  //
  // ABAP RAP equivalent: in the behavior definition you write
  //     managed implementation in class zbp_i_companylayer unique;
  //     strict ( 2 );
  //     with draft;
  // See ../abap-reference/05-behavior/ZI_CompanyLayer.bdef
  @odata.draft.enabled
  // ---- @Capabilities --------------------------------------------------------
  // Capabilities tell the CLIENT what it may do, so Fiori Elements can decide
  // which buttons to render. Here: the user may EDIT a company/layer combination
  // (to maintain its tax rates) but may not CREATE or DELETE combinations -
  // those come from the finance master data, not from this app.
  // Result in the UI: no "Create" button, no "Delete" button, but yes "Edit".
  // ABAP RAP equivalent: simply omitting `create;` and `delete;` from the
  // behavior definition.
  @Capabilities: {
    InsertRestrictions: { Insertable: false },
    DeleteRestrictions: { Deletable : false },

    // ---- The "entry gate" from the project brief ----------------------------
    // RequiredProperties says: the client MUST filter on these fields before it
    // is allowed to ask for data. Fiori Elements reacts by greying out the "Go"
    // button until both Company Code and Layer ID are filled in.
    //
    // That is how "the user must select Company Code + Layer ID before entering
    // the app" is implemented - declaratively, in the backend, with no UI code.
    // Delete these two lines and the app immediately becomes a normal
    // browse-everything list. Try it, it is a good way to feel what annotations do.
    //
    // ABAP CDS equivalent, on the ZC_ projection view:
    //     @UI.selectionField: [{ position: 10 }]
    //     @Consumption.filter: { mandatory: true }
    FilterRestrictions: {
      RequiredProperties: [ companyCode, layerID ]
    }
  }
  entity CompanyLayers as projection on db.CompanyLayers;


  /****************************************************************************
   * THE EDITABLE CHILD
   *
   * We must expose TaxRates as its own entity set even though the user always
   * reaches it through CompanyLayers. Two reasons:
   *   1. OData needs a type + entity set for the rows inside the table
   *   2. we want to hang UI annotations (the table columns) on it
   *
   * Note we do NOT repeat @odata.draft.enabled here. Draft is inherited down a
   * composition: because CompanyLayers is draft-enabled and owns TaxRates,
   * the tax rates are automatically drafted with their parent. Marking a child
   * as a draft root as well would be wrong.
   ****************************************************************************/
  entity TaxRates    as projection on db.TaxRates;


  /****************************************************************************
   * READ-ONLY DATA
   *
   * @readonly is shorthand. CAP expands it into:
   *     @Capabilities.InsertRestrictions.Insertable: false
   *     @Capabilities.UpdateRestrictions.Updatable : false
   *     @Capabilities.DeleteRestrictions.Deletable : false
   * and then actually enforces it - a POST to /GLAccounts returns 405.
   *
   * Rule of thumb, in CAP and in RAP alike: expose read-only by default and
   * open up writing deliberately.
   ****************************************************************************/

  // The balance sheet data behind Tab 2.
  @readonly entity GLAccounts   as projection on db.GLAccounts;

  // The three code lists below exist only to feed the value help (F4) dropdowns
  // on the Screen 1 filter bar. In ABAP these would be separate ZI_* CDS views
  // marked with @ObjectModel.dataCategory: #TEXT or #VALUE_HELP.
  @readonly entity CompanyCodes as projection on db.CompanyCodes;
  @readonly entity Layers       as projection on db.Layers;
  @readonly entity Countries    as projection on db.Countries;
}
