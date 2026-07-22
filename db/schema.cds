/******************************************************************************
 * db/schema.cds  —  THE DATA MODEL
 *
 * WHAT THIS FILE IS
 * -----------------
 * This is a CDS file. CDS = "Core Data Services", SAP's language for describing
 * data models. You will meet CDS twice in your career:
 *
 *   1. CAP CDS   (this file)  -> runs on Node.js, creates SQLite/HANA tables
 *   2. ABAP CDS  (../abap-reference/) -> runs in S/4HANA, creates HANA views
 *
 * They are cousins: same idea, same vocabulary (entity, association, annotation,
 * projection), slightly different syntax. Learning this file means you already
 * understand 80% of the ABAP CDS files in /abap-reference.
 *
 * WHAT AN "ENTITY" IS
 * -------------------
 * An entity is a table. Nothing more mysterious than that. It has fields
 * (called "elements" in CDS) and one or more key fields.
 *
 * ABAP EQUIVALENT OF THIS WHOLE FILE
 * ----------------------------------
 * In ABAP you would create DDIC database tables (SE11 / .tabl objects) plus
 * "interface" CDS views on top of them (ZI_*). See:
 *   ../abap-reference/01-tables/
 *   ../abap-reference/02-cds-interface/
 ******************************************************************************/

// A namespace is just a prefix so our entity names can't collide with anyone
// else's. Full name of the first entity below is: sap.learning.taxbalance.Countries
// ABAP has no namespaces like this - instead everyone prefixes with Z or Y
// (ZI_COUNTRY), because Z/Y is the customer name range reserved by SAP.
namespace sap.learning.taxbalance;


/******************************************************************************
 * 1) COUNTRIES  -  a "code list" / check table
 *
 * Real SAP equivalent: table T005 (Countries).
 ******************************************************************************/

// @cds.odata.valuelist tells the OData layer: "whenever another entity points
// at me, generate a value help (F4 help) dropdown". This is what makes the
// Company Code field on Screen 1 show a searchable dropdown instead of a
// plain text box. In ABAP CDS the equivalent is @Consumption.valueHelpDefinition.
@cds.odata.valuelist
entity Countries {
      // "key" marks the primary key, exactly like KEY in an ABAP DDIC table.
      // String(3) becomes NVARCHAR(3). ABAP equivalent: LAND1 / CHAR3.
  key code : String(3)  @title: 'Country Key';
      name : String(60) @title: 'Country';
}


/******************************************************************************
 * 2) COMPANY CODES
 *
 * A "company code" (Buchungskreis) is the central accounting unit in SAP FI.
 * Every posting belongs to exactly one company code, and a company code
 * belongs to exactly one country. Real SAP equivalent: table T001.
 ******************************************************************************/
@cds.odata.valuelist
entity CompanyCodes {
  key code        : String(4)  @title: 'Company Code';
      name        : String(60) @title: 'Company Name';
      countryCode : String(3)  @title: 'Country Key';

      // ---- ASSOCIATION ----------------------------------------------------
      // An association is a *declared relationship* between two entities.
      // Think "JOIN that you define once and reuse everywhere" - you write the
      // join condition here, and afterwards you can just write `company.country.name`.
      //
      // This is an UNMANAGED association: we spell out the ON condition
      // ourselves. It is written exactly like this in ABAP CDS:
      //
      //     association [0..1] to ZI_Country as _Country
      //       on $projection.CountryCode = _Country.CountryCode
      //
      // "to one" = cardinality 0..1 (a company code has at most one country).
      country     : Association to one Countries
                      on country.code = countryCode;
}


/******************************************************************************
 * 3) LAYERS
 *
 * A "layer" here means an accounting/valuation layer - the same financial facts
 * viewed under different rule sets. In real S/4HANA the closest concepts are
 * the Ledger (0L = leading ledger) and the Accounting Principle (IFRS / HGB).
 * We model it as a small custom code list.
 ******************************************************************************/
@cds.odata.valuelist
entity Layers {
  key ID          : String(2)  @title: 'Layer ID';
      description : String(60) @title: 'Layer Description';
}


/******************************************************************************
 * 4) COMPANY-LAYERS  <-- THE ROOT ENTITY OF OUR APP
 *
 * This is the most important entity to understand.
 *
 * Screen 1 asks the user to pick a Company Code AND a Layer ID. So the thing
 * the user is really selecting is a *combination* of the two. In OData/Fiori
 * Elements, whatever the user selects in the List Report must itself be an
 * entity with a key - you cannot navigate to "a pair of filter values".
 *
 * So we make that pair a real entity with a compound key (companyCode + layerID).
 *   - Screen 1 (List Report)  = a list of CompanyLayers rows, filtered
 *   - Screen 2 (Object Page)  = ONE CompanyLayers row, expanded
 *
 * This entity is also the ROOT of our "business object". In RAP terminology a
 * business object is a tree: one root entity plus its children. Ours is:
 *
 *     CompanyLayers                (root - what you select and edit)
 *      +-- taxRates    [child]     (composition - owned by the root)
 *      +-- glAccounts  [related]   (association - NOT owned, just referenced)
 *
 * ABAP equivalent: ../abap-reference/02-cds-interface/ZI_CompanyLayer.ddls
 ******************************************************************************/
entity CompanyLayers {
      // Compound key: two fields together identify one row.
      // In OData URLs this becomes:
      //   CompanyLayers(companyCode='1000',layerID='01',IsActiveEntity=true)
  key companyCode : String(4) @title: 'Company Code';
  key layerID     : String(2) @title: 'Layer ID';

      // ---- LOOKUPS (read-only convenience associations) --------------------
      company     : Association to one CompanyCodes on company.code = companyCode;
      layer       : Association to one Layers       on layer.ID    = layerID;

      // ---- COMPOSITION vs ASSOCIATION -------------------------------------
      // This is one of the most important distinctions in both CAP and RAP.
      //
      //   ASSOCIATION = "I know about you."     (a reference / a join)
      //   COMPOSITION = "I OWN you."            (parent-child, cascading)
      //
      // Because taxRates is a COMPOSITION:
      //   * deleting a CompanyLayers row deletes its tax rates too
      //   * the tax rates are copied into the draft when you press Edit
      //   * Fiori Elements knows it may create/delete rows inline in the table
      //
      // `on taxRates.parent = $self` is the "backlink": the child has an
      // association called `parent` pointing back at me. $self means "this row".
      //
      // ABAP RAP writes exactly the same idea as:
      //     composition [0..*] of ZI_TaxRate as _TaxRates
      // and in the child:
      //     association to parent ZI_CompanyLayer as _Parent on ...
      taxRates    : Composition of many TaxRates
                      on taxRates.parent = $self;

      // GL accounts are NOT owned by this entity - they are master data that
      // exists independently. So: association, not composition. Deleting a
      // CompanyLayers row must never delete general ledger accounts!
      glAccounts  : Association to many GLAccounts
                      on  glAccounts.companyCode = companyCode
                      and glAccounts.layerID     = layerID;
}


/******************************************************************************
 * 5) TAX RATES  -  the editable child (Tab 1)
 *
 * One row = one named rate the user typed in, e.g. ("VAT Standard", 19.00).
 ******************************************************************************/
entity TaxRates {
      // Why a UUID key instead of (companyCode, layerID, rateType)?
      // Because rateType is FREE TEXT that the user types and can edit. If a
      // field can change, it must not be part of the key - changing a key means
      // deleting a row and inserting another one. A technical UUID key is the
      // standard RAP answer to this, and RAP even has a keyword for it:
      //     key TaxRateUUID : sysuuid_x16;
  key ID       : UUID       @title: 'Technical ID';

      // ---- MANAGED ASSOCIATION --------------------------------------------
      // Note there is no ON condition here. That makes it a MANAGED association:
      // CAP works out the join from the target's key and silently creates the
      // foreign key columns  parent_companyCode  and  parent_layerID  in the
      // database table. This is what lets Fiori Elements create a new tax rate
      // row inline without us writing any glue code - the framework fills the
      // parent keys automatically.
      parent   : Association to one CompanyLayers;

      rateType : String(40)     @title: 'Rate Type';
      // Decimal(5,2) = 5 digits total, 2 after the point -> max 999.99
      // NEVER use a floating point type (Double) for money or rates: 0.1 + 0.2
      // is not 0.3 in binary floating point. ABAP's equivalent correct type is
      // DEC / CURR / abap.dec(5,2). This is a real bug source in finance code.
      rateValue : Decimal(5, 2) @title: 'Rate Value (%)';
}


/******************************************************************************
 * 6) GL ACCOUNTS  -  the read-only data behind Tab 2
 *
 * "GL" = General Ledger. A GL account is a bucket that money is booked into,
 * e.g. 400000 "Raw materials". Real SAP equivalents: SKA1 (chart-of-accounts
 * level), SKB1 (company-code level), ACDOCA (the actual line items in S/4HANA).
 ******************************************************************************/
entity GLAccounts {
      // Compound key of three fields. Same account number can exist for a
      // different company code or a different layer, with a different balance.
  key companyCode      : String(4)  @title: 'Company Code';
  key layerID          : String(2)  @title: 'Layer ID';
  key accountNumber    : String(10) @title: 'G/L Account';

      accountName      : String(60) @title: 'Account Name';

      // @Measures.ISOCurrency tells Fiori Elements "this amount is money, and
      // the currency is in the field named `currency`". The UI then right-aligns
      // it, formats it per the user's locale and prints the currency after it.
      // ABAP CDS uses  @Semantics.amount.currencyCode: 'Currency'  for this.
      @Measures.ISOCurrency: currency
      balanceAmount    : Decimal(15, 2) @title: 'Balance Amount';

      currency         : String(3)  @title: 'Currency';

      // ---- VIRTUAL ELEMENT -------------------------------------------------
      // `virtual` means: this field exists in the OData metadata and shows up in
      // the UI, but there is NO database column behind it. It is filled at
      // runtime by code - see srv/tax-service.js.
      //
      // We must compute it in code rather than in the model because it depends
      // on the tax rates the user typed on Tab 1, which live in another table
      // and change per draft.
      //
      // ABAP CDS has the identical concept and even the identical keyword:
      //     virtual CalculatedAmount : abap.curr(15,2)
      // filled by an ABAP class implementing IF_SADL_EXIT_CALC_ELEMENT_READ.
      // See ../abap-reference/03-cds-projection/ZC_GLAccount.ddls
      @Measures.ISOCurrency: currency
      virtual calculatedAmount : Decimal(15, 2) @title: 'Calculated Amount';
}
